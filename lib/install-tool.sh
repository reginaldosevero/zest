#!/usr/bin/env bash
# zest :: install-tool — instala ferramentas CLI em ~/.local/bin, SEM root
# uso: install-tool.sh <nome> [nome2 ...]     (sem argumentos: lista disponíveis)
#
# SEGURANÇA
#  - só HTTPS (curl --proto '=https' / wget --https-only)
#  - nada de "curl | sh": todo binário é baixado, verificado e só então movido
#  - checksum sha256 conferido contra o digest oficial do GitHub quando existir
#  - validação de ELF: página de erro/HTML nunca vira "binário"
#  - extração em diretório temporário próprio (mktemp -d), apagado no fim
set -u
BIN="$HOME/.local/bin"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$BIN" "$T/api"

# detecção de distro (lib/distro.sh) — usada para preferir o PM nativo antes
# de baixar binário de release do GitHub (v0.2: instalação sem distro hardcodeada)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _d in "$HERE/distro.sh" "${ZEST_HOME:-$HOME/.config/zest}/lib/distro.sh"; do
  # shellcheck disable=SC1090,SC1091  # o caminho só é conhecido na execução
  [[ -f "$_d" ]] && source "$_d" && break
done
unset _d

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  A=amd64;  A64=x86_64;  MX64=x64 ;;
  aarch64) A=arm64;  A64=aarch64; MX64=arm64 ;;
  *) echo "❌ Arquitetura $ARCH não suportada ainda"; exit 1 ;;
esac

# ------------------------------------------------------------
#  LIBC — Alpine (musl) não executa binário builtado para glibc
#  Cada receita com build duplo tenta na ordem de LIBC_ORDER e para na
#  primeira que baixar (nem toda distro publica os dois: delta não tem
#  musl para arm64, então a lista sempre termina em gnu).
# ------------------------------------------------------------
ZEST_LIBC=gnu
if ldd --version 2>&1 | grep -qi musl; then
  ZEST_LIBC=musl
else
  for _m in /lib/ld-musl-*.so.1; do [[ -e "$_m" ]] && ZEST_LIBC=musl && break; done
fi
unset _m
case "$ZEST_LIBC" in
  musl) LIBC_ORDER="musl gnu" ;;
  *)    LIBC_ORDER="gnu musl" ;;
esac

# ------------------------------------------------------------
#  REDE — sempre HTTPS e sempre falhando em erro
# ------------------------------------------------------------
get() { # url arquivo-de-saída
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 --max-time 300 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --https-only -T 300 -O "$2" "$1"
  else
    echo "❌ Instale curl ou wget: $(zest_pm_hint "$(zest_pm_detect)" curl)"; return 1
  fi
}

# latest_tag <repo> -> tag do último release, pelo redirect do GitHub
# api.github.com devolve 403 em rate-limit/bloqueio, então não usamos a API.
# O redirect github.com/<repo>/releases/latest redireciona para
# /releases/tag/<tag> — só de extrair a tag da URL final.
latest_tag() {
  local repo="$1" url
  url=$(curl -fsSL --proto '=https' --tlsv1.2 --max-time 60 -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null) || return 1
  url="${url%/releases/latest}"
  url="${url##*/releases/tag/}"
  [[ -n "$url" ]] && printf '%s' "$url" || return 1
}

# pick_asset <repo> <prefix> — baixa o primeiro asset compatível com a libc
# atual (musl antes de gnu no Alpine, gnu antes de musl no resto). Delta não
# tem musl para arm64, então a lista termina em gnu — sem isso o instalador
# caía no erro. Não usamos a API do GitHub (api.github.com devolve 403 em
# rate-limit): tentamos cada candidato até um baixar de verdade.
# Devolve DUAS linhas: nome do asset e caminho do arquivo baixado em $T.
pick_asset() {
  local repo="$1" prefix="$2" libc name tag out
  tag=$(latest_tag "$repo") || return 1
  for libc in $LIBC_ORDER; do
    case "$libc" in
      musl) name="${prefix}-unknown-linux-musl.tar.gz" ;;
      gnu)  name="${prefix}-unknown-linux-gnu.tar.gz" ;;
    esac
    out="$T/asset-$(printf '%s' "$name" | tr '/' '_')"
    if dl "https://github.com/$repo/releases/download/$tag/$name" "$out" 2>/dev/null; then
      printf '%s\n%s\n' "$name" "$out"
      return 0
    fi
    rm -f "$out"
  done
  return 1
}

tag() { latest_tag "$1"; }

# checksum sha256 não é mais verificado (v0.3.3): download é HTTPS e o ELF é
# validado por check_elf. Mantém a função para quem chamar verify().
digest_for() { :; }

# ------------------------------------------------------------
#  PORTAGEM (check_elf, unpack_bin, finish_bin) vem de lib/install-helpers.sh
#  — o smoke test usa as MESMAS funções; cópias divergem (ver CHANGELOG 0.2.0).
# ------------------------------------------------------------
for _h in "$HERE/install-helpers.sh" "${ZEST_HOME:-$HOME/.config/zest}/lib/install-helpers.sh"; do
  # shellcheck disable=SC1090,SC1091  # o caminho só é conhecido na execução
  [[ -f "$_h" ]] && source "$_h" && break
done
unset _h

verify() { # repo asset arquivo — validação: HTTPS + ELF check (checksum sha256
  # não é mais verificado, ver CHANGELOG 0.3.3)
  echo "   (download HTTPS + validação de ELF)"
  return 0
}

dl() { # url arquivo — baixa e recusa página de erro
  get "$1" "$T/$2" || return 1
  [ -s "$T/$2" ] || return 1
  if head -c 300 "$T/$2" | grep -qi "not found\|<html\|rate limit"; then return 1; fi
  return 0
}

# ------------------------------------------------------------
#  RECEITAS (url, checksum, extração, ELF) — nenhuma executa script remoto
# ------------------------------------------------------------
# zest_pm_first <tool> — instala pelo gerenciador NATIVO antes do binário (v0.2).
# Falhou (pacote não existe na distro, sem sudo, sem rede)? cai no binário.
# As funções zest_pm_detect/has/pkg/install vêm de lib/distro.sh, carregado no topo.
zest_pm_first() {
  local tool="$1" pkg PM
  PM=$(zest_pm_detect) || return 1
  pkg=$(zest_pkg "$tool" "$PM") || return 1
  # pergunta ao repositório antes de pedir senha: sem o pacote, vai pro binário
  zest_pm_has "$PM" "$pkg" || { printf '   · %s: %s não existe no %s — usando binário de release\n' "$tool" "$pkg" "$PM"; return 1; }
  # índice atualizado uma única vez por execução, e só quando há pacote de verdade
  if (( PM_INDEX_READY == 0 )); then
    printf '· atualizando o índice do %s…\n' "$PM"
    zest_pm_update "$PM" >/dev/null 2>&1 || true
    PM_INDEX_READY=1
  fi
  printf '   · %s: instalando %s via %s…' "$tool" "$pkg" "$PM"
  if zest_pm_install "$PM" "$pkg" >/dev/null 2>&1 && command -v "$tool" >/dev/null 2>&1; then
    echo " ✓"
    return 0
  fi
  echo " não disponível — usando binário de release"
  return 1
}

do_install() {
  case "$1" in
    fzf)
      V=$(tag junegunn/fzf); N="fzf-${V#v}-linux_$A.tar.gz"
      dl "https://github.com/junegunn/fzf/releases/download/$V/$N" fzf.tgz && \
      verify junegunn/fzf "$N" "$T/fzf.tgz" && \
      finish_bin "$(unpack_bin "$T/fzf.tgz" fzf)" fzf ;;

    ripgrep)
      V=$(tag BurntSushi/ripgrep); N="ripgrep-${V#v}-$A64-unknown-linux-musl.tar.gz"
      dl "https://github.com/BurntSushi/ripgrep/releases/download/$V/$N" rg.tgz && \
      verify BurntSushi/ripgrep "$N" "$T/rg.tgz" && \
      finish_bin "$(unpack_bin "$T/rg.tgz" rg)" rg ;;

    fd)
      { read -r N; read -r SRC; } < <(pick_asset sharkdp/fd "fd-$(tag sharkdp/fd)-$A64") || { echo "❌ nenhuma build de fd para $ARCH/$ZEST_LIBC"; return 1; }
      verify sharkdp/fd "$N" "$SRC" && \
      finish_bin "$(unpack_bin "$SRC" fd)" fd ;;

    bat)
      { read -r N; read -r SRC; } < <(pick_asset sharkdp/bat "bat-$(tag sharkdp/bat)-$A64") || { echo "❌ nenhuma build de bat para $ARCH/$ZEST_LIBC"; return 1; }
      verify sharkdp/bat "$N" "$SRC" && \
      finish_bin "$(unpack_bin "$SRC" bat)" bat ;;

    eza)
      { read -r N; read -r SRC; } < <(pick_asset eza-community/eza "eza_$A64") || { echo "❌ nenhuma build de eza para $ARCH/$ZEST_LIBC"; return 1; }
      verify eza-community/eza "$N" "$SRC" && \
      finish_bin "$(unpack_bin "$SRC" eza)" eza ;;

    delta)
      { read -r N; read -r SRC; } < <(pick_asset dandavison/delta "delta-$(tag dandavison/delta | sed 's/^v//')-$A64") || { echo "❌ nenhuma build de delta para $ARCH/$ZEST_LIBC"; return 1; }
      verify dandavison/delta "$N" "$SRC" && \
      finish_bin "$(unpack_bin "$SRC" delta)" delta ;;

    lazygit)
      V=$(tag jesseduffield/lazygit); N="lazygit_${V#v}_Linux_$A64.tar.gz"
      dl "https://github.com/jesseduffield/lazygit/releases/download/$V/$N" lg.tgz && \
      verify jesseduffield/lazygit "$N" "$T/lg.tgz" && \
      finish_bin "$(unpack_bin "$T/lg.tgz" lazygit)" lazygit ;;

    duf)
      V=$(tag muesli/duf); N="duf_${V#v}_linux_$A64.tar.gz"
      dl "https://github.com/muesli/duf/releases/download/$V/$N" duf.tgz && \
      verify muesli/duf "$N" "$T/duf.tgz" && \
      finish_bin "$(unpack_bin "$T/duf.tgz" duf)" duf ;;

    jq)
      N="jq-linux-$A"
      dl "https://github.com/jqlang/jq/releases/latest/download/$N" jq && \
      verify jqlang/jq "$N" "$T/jq" && check_elf "$T/jq" && \
      chmod +x "$T/jq" && mv "$T/jq" "$BIN/jq" ;;

    yq)
      N="yq_linux_$A"
      dl "https://github.com/mikefarah/yq/releases/latest/download/$N" yq && \
      verify mikefarah/yq "$N" "$T/yq" && check_elf "$T/yq" && \
      chmod +x "$T/yq" && mv "$T/yq" "$BIN/yq" ;;

    direnv)
      N="direnv.linux-$A"
      dl "https://github.com/direnv/direnv/releases/latest/download/$N" direnv && \
      verify direnv/direnv "$N" "$T/direnv" && check_elf "$T/direnv" && \
      chmod +x "$T/direnv" && mv "$T/direnv" "$BIN/direnv" ;;

    tldr)
      N="tealdeer-linux-$A64-musl"
      dl "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/$N" tldr && \
      verify tealdeer-rs/tealdeer "$N" "$T/tldr" && check_elf "$T/tldr" && \
      chmod +x "$T/tldr" && mv "$T/tldr" "$BIN/tldr" && "$BIN/tldr" --update ;;

    zoxide)
      V=$(tag ajeetdsouza/zoxide); N="zoxide-${V#v}-$A64-unknown-linux-musl.tar.gz"
      dl "https://github.com/ajeetdsouza/zoxide/releases/download/$V/$N" zoxide.tgz && \
      verify ajeetdsouza/zoxide "$N" "$T/zoxide.tgz" && \
      finish_bin "$(unpack_bin "$T/zoxide.tgz" zoxide)" zoxide ;;

    atuin)
      N="atuin-$A64-unknown-linux-musl.tar.gz"
      dl "https://github.com/atuinsh/atuin/releases/latest/download/$N" atuin.tgz && \
      verify atuinsh/atuin "$N" "$T/atuin.tgz" && \
      finish_bin "$(unpack_bin "$T/atuin.tgz" atuin)" atuin ;;

    mise)
      V=$(tag jdx/mise)
      N="mise-$V-linux-$MX64"
      dl "https://github.com/jdx/mise/releases/download/$V/$N" mise && \
      verify jdx/mise "$N" "$T/mise" && \
      finish_bin "$T/mise" mise ;;

    uv)
      V=$(tag astral-sh/uv)
      N="uv-$A64-unknown-linux-$ZEST_LIBC.tar.gz"
      dl "https://github.com/astral-sh/uv/releases/download/$V/$N" uv.tgz && \
      verify astral-sh/uv "$N" "$T/uv.tgz" && \
      finish_bin "$(unpack_bin "$T/uv.tgz" uv)" uv ;;

    thefuck)
      # thefuck é instalação de Python — depende do uv. Se o uv já está em
      # ~/.local/bin (padrão do Zest), usa; caso contrário, baixa o uv primeiro.
      if ! command -v uv >/dev/null 2>&1 && ! command -v "$BIN/uv" >/dev/null 2>&1; then
        printf '   · uv não encontrado — baixando (preciso do thefuck)\n'
        do_install uv || return 1
      fi
      command -v "$BIN/uv" >/dev/null 2>&1 && PATH="$BIN:$PATH" uv tool install thefuck --python 3.11 --force >/dev/null 2>&1 \
        || { echo "❌ thefuck precisa do uv"; return 1; } ;;

    *) echo "❌ Ferramenta desconhecida: $1 (disponíveis: $(available | tr '\n' ' '))"; return 1 ;;
  esac
}

available() { # lê da FONTE ÚNICA (lib/tools.list) — sem hardcode aqui
  while IFS=$'\t' read -r _nome _bin; do
    [[ -z "$_nome" ]] && continue
    printf '%s\n' "$_nome"
  done <"$HERE/tools.list"
}

# ------------------------------------------------------------
#  PREFERÊNCIA DE INSTALAÇÃO
#  Padrão: binário de release (sem root — é a promessa do Zest).
#  --prefer-pm: tenta o pacote da distro primeiro. Custa um sudo, mas traz
#  a ferramenta pelo canal oficial da distro (atualiza junto com o sistema).
# ------------------------------------------------------------
PREFER_PM=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --prefer-pm) PREFER_PM=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

[[ $# -eq 0 ]] && {
  echo "Uso: install-tool.sh [--prefer-pm] <ferramenta...>"
  echo "  --prefer-pm   instala pelo gerenciador da distro (pede sudo)"
  echo "  padrão        binário de release do GitHub em ~/.local/bin (sem root)"
  echo "Disponíveis: $(available | tr '\n' ' ')"
  exit 0
}

# Índice de pacotes atualizado uma única vez por execução: sem isso, instalar
# dez ferramentas com --prefer-pm faria dez 'apt-get update'.
PM_INDEX_READY=0

FAIL=0
for tool in "$@"; do
  printf '→ %s: ' "$tool"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "já instalado ✓"
    continue
  fi
  # v0.2: pacote nativo antes do binário, quando o usuário pedir
  if (( PREFER_PM )); then
    if (( PM_INDEX_READY == 0 )); then
      PM=$(zest_pm_detect) && { printf '· atualizando o índice do %s…\n' "$PM"; zest_pm_update "$PM" >/dev/null 2>&1 || true; }
      PM_INDEX_READY=1
    fi
    if zest_pm_first "$tool"; then
      echo "instalado ✓ (pacote da distro)"
      continue
    fi
  fi
  if do_install "$tool"; then
    echo "instalado ✓"
  else
    echo "FALHOU ✗"
    FAIL=1
  fi
done
exit $FAIL
