#!/usr/bin/env bash
# zest :: install — instala o Zest sem root, sem destruir nada
# princípios: aditivo (nunca remove), idempotente (rodar 2x = igual), reversível
set -euo pipefail

# locale: VMs recém-instaladas podem vir sem UTF-8 (locale C) — os emojis dos
# avisos e o python3 quebram. C.UTF-8 existe em qualquer distro moderna.
if command locale -a 2>/dev/null | grep -qi '^C\.utf8$'; then
  export LANG=C.UTF-8 LC_ALL=C.UTF-8
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# detecção de distro (lib/distro.sh) — usada no passo 1 e no install-tool
source "$REPO_DIR/lib/distro.sh"
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"
WITH_PLUGINS=0
WITH_OMZ=0
WITH_TOOLS=1
for arg in "$@"; do
  case $arg in
    --with-plugins) WITH_PLUGINS=1 ;;
    --with-omz)     WITH_OMZ=1; WITH_PLUGINS=1 ;;   # instala o Oh My Zsh se faltar
    --no-tools)     WITH_TOOLS=0 ;;                   # CI: pula as 17 ferramentas
  esac
done

echo "🌶️  Zest — instalação"
echo "═══════════════════════════════════════"

# 0) escolha do prompt — o que o terminal vai parecer
#   (só pergunta em terminal interativo; em CI, o default é "zest")
mkdir -p "$DEST"
if [[ -t 0 && -z "${ZEST_PROMPT:-}" && ! -f "$DEST/prompt" ]]; then
  echo ""
  echo "🎨 Prompt do terminal"
  echo "   O Zest não exige Oh My Zsh, então o prompt vem dele mesmo."
  echo "   (Se já tem Oh My Zsh, starship ou powerlevel10k, o Zest não toca em nada.)"
  echo ""
  echo "   1) zest   ╭─usuário@máquina ~/dir ❯  com status do git  (recomendado)"
  echo "   2) compact  ~/dir ❯  (uma linha, leve)"
  echo "   3) plain   usuário@máquina ~/dir$  (sem cor)"
  echo "   4) off     não mexo no prompt (você configura depois)"
  printf "   Qual? [1] "
  read -r _zest_escolha
  case "${_zest_escolha:-1}" in
    2) echo "compact" > "$DEST/prompt" ;;
    3) echo "plain"    > "$DEST/prompt" ;;
    4) echo "off"      > "$DEST/prompt" ;;
    *) echo "zest"      > "$DEST/prompt" ;;
  esac
  unset _zest_escolha
fi

# 1) dependências — o Zest instala SOZINHO o que falta (sudo, ou su no Debian cru)
NEED=()
command -v zsh >/dev/null 2>&1 || NEED+=(zsh)
command -v git >/dev/null 2>&1 || NEED+=(git)
command -v curl >/dev/null 2>&1 || NEED+=(curl)
if [[ $WITH_PLUGINS == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  command -v python3 >/dev/null 2>&1 || NEED+=(python3)
fi

if (( ${#NEED[@]} )); then
  PM=$(zest_pm_detect) || PM=""
  if [[ -z "$PM" ]]; then
    echo "❌ Faltam: ${NEED[*]} — e não encontrei apt/dnf/pacman/zypper/apk para instalá-los."
    echo "   Instale manualmente e rode este instalador de novo."
    exit 1
  fi

  echo "📦 Faltam dependências: ${NEED[*]}"
  echo "   Gerenciador detectado: $PM — pode pedir sua senha (sudo) ou a do root (su)…"
  zest_pm_update "$PM" || true
  if zest_pm_install "$PM" "${NEED[@]}"; then
    echo "✓ dependências instaladas (via $PM)"
  else
    echo "❌ Não consegui instalar automaticamente. Faça manualmente e rode de novo:"
    case "$PM" in
      apt-get) echo "   sudo apt-get install ${NEED[*]}" ;;
      dnf)     echo "   sudo dnf install ${NEED[*]}" ;;
      pacman)  echo "   sudo pacman -Sy --noconfirm ${NEED[*]}" ;;
      zypper)  echo "   sudo zypper install -y ${NEED[*]}" ;;
      apk)     echo "   sudo apk add ${NEED[*]}" ;;
    esac
    exit 1
  fi
fi
echo "✓ zsh encontrado: $(zsh --version)"

# 2) Oh My Zsh: instala ANTES de mexer no .zshrc (para ele criar o template com plugins=())
# Créditos: Oh My Zsh é projeto de Robby Russell e comunidade — https://ohmyzsh.com (MIT)
if [[ $WITH_OMZ == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "· Oh My Zsh não encontrado — instalando por clone (sem executar script remoto)…"
  # clone em vez de "curl | sh": nenhum código remoto é executado às cegas.
  # Créditos: Oh My Zsh é projeto de Robby Russell e comunidade — https://ohmyzsh.com (MIT)
  # Obs.: o upstream não publica tags/releases — só o branch master. Clonamos
  # com --single-branch e registramos o commit SHA exato em .zest-omz-pin para
  # auditoria/reprodutibilidade (mesmo espírito dos plugins pinados por tag).
  if git clone --depth 1 --single-branch --branch master -q \
       https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" 2>/dev/null; then
    # registra o commit efetivamente instalado (auditoria posterior / rollback)
    ( cd "$HOME/.oh-my-zsh" && git rev-parse HEAD >"$HOME/.oh-my-zsh/.zest-omz-pin" ) 2>/dev/null || true
    # mesmo comportamento do instalador oficial: .zshrc nasce do template
    if [[ ! -f "$ZSHRC" ]]; then
      cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
      echo "✓ .zshrc criado a partir do template do Oh My Zsh"
    fi
    omz_sha=$(cat "$HOME/.oh-my-zsh/.zest-omz-pin" 2>/dev/null | cut -c1-7)
    echo "✓ Oh My Zsh instalado em ~/.oh-my-zsh (commit ${omz_sha:-?})"
  else
    echo "⚠️  clone do Oh My Zsh falhou — seguindo em modo standalone (plugins carregados pelo módulo 10)"
  fi
fi

# 3) copia módulos e lib (idempotente)
mkdir -p "$DEST"
cp -r "$REPO_DIR/modules" "$REPO_DIR/lib" "$DEST/" 2>/dev/null || true
mkdir -p "$DEST/modules" "$DEST/lib"
cp "$REPO_DIR"/modules/*.zsh "$DEST/modules/"
[[ -d "$REPO_DIR/lib" ]] && cp -r "$REPO_DIR"/lib/* "$DEST/lib/" 2>/dev/null || true
chmod +x "$REPO_DIR/bin/zest"
mkdir -p "$HOME/.local/bin"
cp "$REPO_DIR/bin/zest" "$HOME/.local/bin/zest"   # cópia (não symlink): sobrevive se a pasta do clone for apagada
echo "✓ comando 'zest' em $HOME/.local/bin"
echo "✓ módulos em $DEST"

# 4) backup do .zshrc (uma vez por dia, sem acumular)
if [[ -f "$ZSHRC" ]]; then
  BAK="$ZSHRC.zest-bak-$(date +%Y%m%d)"
  # -p preserva permissões: um .zshrc 600 (com tokens) não vira backup 644
  [[ -f "$BAK" ]] || cp -p "$ZSHRC" "$BAK"
  echo "✓ backup: $BAK"
fi

# 5) bloco marcado no .zshrc (nunca duplica)
if grep -q ">>> zest >>>" "$ZSHRC" 2>/dev/null; then
  echo "✓ .zshrc já carrega o Zest (nada duplicado)"
else
  cat >> "$ZSHRC" <<'EOF'

# >>> zest >>>
# Zest 🌶️ — o tempero do seu terminal (https://github.com/reginaldosevero/zest)
# Remoção limpa: rode o uninstall.sh do repositório
export ZEST_HOME="$HOME/.config/zest"
for _zmod in "$ZEST_HOME"/modules/*.zsh(N); do source "$_zmod"; done
unset _zmod
# <<< zest <<<
EOF
  echo "✓ bloco acrescentado ao final do $ZSHRC (nada do que já existia foi alterado)"
fi

# 6) plugins do zsh (opcional, com --with-plugins)
if [[ $WITH_PLUGINS == 1 ]]; then
  declare -A REPOS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions v0.7.1"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting 0.8.0"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions 0.36.0"
    [zsh-history-substring-search]="https://github.com/zsh-users/zsh-history-substring-search v1.1.0"
    [zsh-autopair]="https://github.com/hlissner/zsh-autopair v1.0"
  )

  # 6a) Com Oh My Zsh: plugins em custom/plugins + lista plugins=()
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    CUST="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$CUST"
    for p in "${!REPOS[@]}"; do
      if [[ ! -d "$CUST/$p" ]]; then
        read -r _url _ref <<< "${REPOS[$p]}"
        git clone --depth 1 --branch "$_ref" -q "$_url" "$CUST/$p" && echo "✓ plugin clonado: $p ($_ref)"
      fi
    done
    PYTHONIOENCODING=utf-8 python3 - "$ZSHRC" "${!REPOS[@]}" <<'PYEOF'
import re, sys
path, want = sys.argv[1], sys.argv[2:]
src = open(path, encoding="utf-8").read()
# auto-cura: a v0.1.2 deixou um ')' órfão após o comentário de exemplo do omz
# (quebrava bash E zsh). Só remove se a linha anterior for comentário.
src = re.sub(r'(^#[^\n]*zsh-syntax-highlighting[^\n]*\n)\)\n', r'\1', src, flags=re.MULTILINE)
# âncora no INÍCIO da linha: o template do omz tem um COMENTÁRIO de exemplo
# ("# Example format: plugins=(rails ...)") que não pode casar — só o bloco real
m = re.search(r'^plugins=\(([^)]*)\)', src, re.MULTILINE)
if not m:
    print("OK: nenhuma lista plugins=() encontrada - plugins ficam no modo standalone")
    sys.exit(0)
have = set(re.findall(r'[\w-]+', m.group(1)))
add = [w for w in want if w not in have]
if add:
    bloco = m.group(0)[:-1] + ' ' + ' '.join(add) + ')'
    src = src[:m.start()] + bloco + src[m.end():]
    open(path, "w", encoding="utf-8").write(src)
    print("OK: plugins acrescentados a plugins=():", ' '.join(add))
else:
    print("OK: todos os plugins ja estao na lista")
PYEOF
    grep -q '^plugins=.*zsh-autosuggestions' "$ZSHRC" && echo "✓ lista plugins=() verificada de verdade"
  # 6c) Sem Oh My Zsh: plugins em ~/.config/zest/plugins (módulo 10 carrega)
  else
    PDIR="$DEST/plugins"
    mkdir -p "$PDIR"
    for p in "${!REPOS[@]}"; do
      if [[ ! -d "$PDIR/$p" ]]; then
        read -r _url _ref <<< "${REPOS[$p]}"
        git clone --depth 1 --branch "$_ref" -q "$_url" "$PDIR/$p" && echo "✓ plugin standalone: $p ($_ref)"
      fi
    done
  fi
fi

echo "═══════════════════════════════════════"
# 7) ferramentas — todas por padrão, via install-tool (zero root, sem sudo)
#    O CI passa --no-tools para o ciclo ficar rápido; o usuário comum recebe
#    tudo. O baixar falha em alguma? o próximo passo (shell) e o doctor
#    mostram o que faltou, e o usuário pode rodar "zest add <ferramenta>".
if (( WITH_TOOLS )); then
  echo ""
  echo "🔧 Instalando as 17 ferramentas (sem root, em ~/.local/bin)"
  echo "   Isso baixa ~60 MB e pode levar um minuto — o terminal fica livre."
  # nomes da primeira coluna de lib/tools.list (a segunda é o binário real, que
  # o install-tool já descobre sozinho)
  TOOLS_LIST=$(sed 's/[[:space:]]*$//' "$REPO_DIR/lib/tools.list" | grep -v '^#' | grep -v '^$' | awk '{print $1}')
  if bash "$REPO_DIR/lib/install-tool.sh" $TOOLS_LIST; then
    echo "✓ todas as ferramentas em $HOME/.local/bin"
  else
    echo "⚠️  Algumas ferramentas não instalaram — rode 'zest add <nome>' para ver"
    echo "   o erro de cada uma (e corrigir uma a uma)."
  fi
else
  echo "· ferramentas puladas (--no-tools)"
fi

# 8) shell padrão — se ainda for bash (ou outro), o Zest nunca carrega num terminal novo
CURSHELL=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
[[ -z "$CURSHELL" ]] && CURSHELL="${SHELL:-/bin/bash}"
ZSHBIN="$(command -v zsh)"
if [[ "$CURSHELL" != "$ZSHBIN" ]]; then
  echo ""
  echo "⚠️  Seu shell padrão é $CURSHELL — os comandos do Zest SÓ funcionam no zsh!"
  if [[ -t 0 ]]; then
    read -r -p "   Trocar o shell padrão para zsh agora? [S/n] " TROCA
    if [[ ! "$TROCA" =~ ^[nN] ]]; then
      if chsh -s "$ZSHBIN" 2>/dev/null; then
        echo "✓ Shell padrão alterado! Feche e abra o terminal para entrar no zsh."
      else
        echo "   O chsh pediu algo que não deu aqui — com root funciona direto:"
        echo "     su -c \"chsh -s $ZSHBIN $(id -un)\""
      fi
    fi
  else
    echo "   Troque com:  chsh -s $ZSHBIN   (ou: su -c \"chsh -s $ZSHBIN $(id -un)\")"
  fi
fi

echo "✅ Pronto! Ative com:  source ~/.zshrc   (ou abra um terminal novo)"
echo "   Diagnóstico:        zest doctor"
echo "   Ferramentas:        fzf · rg · fd · bat · eza · delta · zoxide · jq · yq · duf · lazygit · direnv · tldr · atuin · mise · uv · thefuck"
echo "   Prompt:             $(cat "$DEST/prompt" 2>/dev/null || echo off) (troque com: ZEST_PROMPT=compact|plain|off)"
echo "   Ferramentas (opcional, sem root):  zest add fzf bat eza ripgrep fd delta lazygit duf jq yq direnv tldr zoxide atuin mise"
