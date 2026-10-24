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

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  A=amd64;  A64=x86_64;  MX64=x64 ;;
  aarch64) A=arm64;  A64=aarch64; MX64=arm64 ;;
  *) echo "❌ Arquitetura $ARCH não suportada ainda"; exit 1 ;;
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
    echo "❌ Instale curl ou wget: sudo apt install -y curl"; return 1
  fi
}

release_json() { # repo -> json do último release (cacheado na sessão)
  local f="$T/api/${1//\//_}.json"
  [[ -s "$f" ]] || get "https://api.github.com/repos/$1/releases/latest" "$f" || return 1
  cat "$f"
}

tag() {
  release_json "$1" | tr -d '\n' \
    | grep -oE '"tag_name": *"[^"]+"' | head -1 \
    | sed -E 's/.*"([^"]+)"$/\1/'
}

digest_for() { # repo asset -> sha256 oficial (vazio se o GitHub não informar)
  local re
  re=$(printf '%s' "$2" | sed 's/[.[\*^$]/\\&/g')
  release_json "$1" | tr '{,' '\n\n' \
    | awk -v want="\"name\": *\"$re\"" '
        $0 ~ want       { found = 1; next }
        $0 ~ /"name":/ { found = 0 }
        found && $0 ~ /"digest":/ {
          if (match($0, /sha256:[0-9a-f]+/)) { print substr($0, RSTART+7, RLENGTH-7); exit }
        }'
}

check_elf() { # arquivo — é um binário ELF de verdade?
  [[ "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "7f454c46" ]]
}

verify() { # repo asset arquivo — confere o sha256 publicado pelo GitHub
  local want got
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "   (sha256sum indisponível — pulando checksum)"
    return 0
  fi
  want=$(digest_for "$1" "$2")
  if [[ -z "$want" ]]; then
    echo "   (upstream sem checksum publicado — validando só o formato)"
    return 0
  fi
  got=$(sha256sum "$3" | awk '{print $1}')
  if [[ "$got" != "$want" ]]; then
    echo ""
    echo "   ❌ CHECKSUM NÃO CONFERE — download descartado"
    echo "      esperado: $want"
    echo "      obtido:   $got"
    return 1
  fi
  echo "   ✓ checksum sha256 confere"
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
do_install() {
  case "$1" in
    fzf)
      V=$(tag junegunn/fzf); N="fzf-${V#v}-linux_$A.tar.gz"
      dl "https://github.com/junegunn/fzf/releases/download/$V/$N" fzf.tgz && \
      verify junegunn/fzf "$N" "$T/fzf.tgz" && \
      tar xzf "$T/fzf.tgz" -C "$T" fzf && check_elf "$T/fzf" && mv "$T/fzf" "$BIN/fzf" ;;

    ripgrep)
      V=$(tag BurntSushi/ripgrep); N="ripgrep-${V#v}-$A64-unknown-linux-musl.tar.gz"
      dl "https://github.com/BurntSushi/ripgrep/releases/download/$V/$N" rg.tgz && \
      verify BurntSushi/ripgrep "$N" "$T/rg.tgz" && \
      tar xzf "$T/rg.tgz" -C "$T" && check_elf "$T/ripgrep-${V#v}-$A64-unknown-linux-musl/rg" && \
      mv "$T/ripgrep-${V#v}-$A64-unknown-linux-musl/rg" "$BIN/rg" ;;

    fd)
      V=$(tag sharkdp/fd); N="fd-${V}-$A64-unknown-linux-gnu.tar.gz"
      dl "https://github.com/sharkdp/fd/releases/download/$V/$N" fd.tgz && \
      verify sharkdp/fd "$N" "$T/fd.tgz" && \
      tar xzf "$T/fd.tgz" -C "$T" && check_elf "$T/fd-${V}-$A64-unknown-linux-gnu/fd" && \
      mv "$T/fd-${V}-$A64-unknown-linux-gnu/fd" "$BIN/fd" ;;

    bat)
      V=$(tag sharkdp/bat); N="bat-${V}-$A64-unknown-linux-gnu.tar.gz"
      dl "https://github.com/sharkdp/bat/releases/download/$V/$N" bat.tgz && \
      verify sharkdp/bat "$N" "$T/bat.tgz" && \
      tar xzf "$T/bat.tgz" -C "$T" && check_elf "$T/bat-${V}-$A64-unknown-linux-gnu/bat" && \
      mv "$T/bat-${V}-$A64-unknown-linux-gnu/bat" "$BIN/bat" ;;

    eza)
      V=$(tag eza-community/eza); N="eza_$A64-unknown-linux-gnu.tar.gz"
      dl "https://github.com/eza-community/eza/releases/download/$V/$N" eza.tgz && \
      verify eza-community/eza "$N" "$T/eza.tgz" && \
      tar xzf "$T/eza.tgz" -C "$T" && check_elf "$T/eza" && mv "$T/eza" "$BIN/eza" ;;

    delta)
      V=$(tag dandavison/delta); N="delta-${V#v}-$A64-unknown-linux-gnu.tar.gz"
      dl "https://github.com/dandavison/delta/releases/download/$V/$N" delta.tgz && \
      verify dandavison/delta "$N" "$T/delta.tgz" && \
      tar xzf "$T/delta.tgz" -C "$T" && check_elf "$T/delta-${V#v}-$A64-unknown-linux-gnu/delta" && \
      mv "$T/delta-${V#v}-$A64-unknown-linux-gnu/delta" "$BIN/delta" ;;

    lazygit)
      V=$(tag jesseduffield/lazygit); N="lazygit_${V#v}_Linux_$A64.tar.gz"
      dl "https://github.com/jesseduffield/lazygit/releases/download/$V/$N" lg.tgz && \
      verify jesseduffield/lazygit "$N" "$T/lg.tgz" && \
      tar xzf "$T/lg.tgz" -C "$T" lazygit && check_elf "$T/lazygit" && mv "$T/lazygit" "$BIN/lazygit" ;;

    duf)
      V=$(tag muesli/duf); N="duf_${V#v}_linux_$A64.tar.gz"
      dl "https://github.com/muesli/duf/releases/download/$V/$N" duf.tgz && \
      verify muesli/duf "$N" "$T/duf.tgz" && \
      tar xzf "$T/duf.tgz" -C "$T" duf && check_elf "$T/duf" && mv "$T/duf" "$BIN/duf" ;;

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
      tar xzf "$T/zoxide.tgz" -C "$T" zoxide && check_elf "$T/zoxide" && mv "$T/zoxide" "$BIN/zoxide" ;;

    atuin)
      N="atuin-$A64-unknown-linux-musl.tar.gz"
      dl "https://github.com/atuinsh/atuin/releases/latest/download/$N" atuin.tgz && \
      verify atuinsh/atuin "$N" "$T/atuin.tgz" && \
      tar xzf "$T/atuin.tgz" -C "$T" atuin && check_elf "$T/atuin" && mv "$T/atuin" "$BIN/atuin" ;;

    mise)
      V=$(tag jdx/mise); N="mise-$V-linux-$MX64"
      dl "https://github.com/jdx/mise/releases/download/$V/$N" mise && \
      verify jdx/mise "$N" "$T/mise" && check_elf "$T/mise" && \
      chmod +x "$T/mise" && mv "$T/mise" "$BIN/mise" ;;

    thefuck)
      command -v uv >/dev/null 2>&1 && uv tool install thefuck --python 3.11 --force >/dev/null 2>&1 ;;

    *) echo "❌ Ferramenta desconhecida: $1 (disponíveis: $(available | tr '\n' ' '))"; return 1 ;;
  esac
}

available() { printf '%s\n' fzf ripgrep fd bat eza delta lazygit duf jq yq direnv tldr zoxide atuin mise thefuck; }

[[ $# -eq 0 ]] && { echo "Uso: install-tool.sh <ferramenta...>"; echo "Disponíveis: $(available | tr '\n' ' ')"; exit 0; }

FAIL=0
for tool in "$@"; do
  printf '→ %s: ' "$tool"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "já instalado ✓"
    continue
  fi
  if do_install "$tool"; then
    echo "instalado ✓"
  else
    echo "FALHOU ✗"
    FAIL=1
  fi
done
exit $FAIL
