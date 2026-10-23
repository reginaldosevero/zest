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
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"
WITH_PLUGINS=0
WITH_OMZ=0
for arg in "$@"; do
  case $arg in
    --with-plugins) WITH_PLUGINS=1 ;;
    --with-omz)     WITH_OMZ=1; WITH_PLUGINS=1 ;;   # instala o Oh My Zsh se faltar
  esac
done

echo "🌶️  Zest — instalação"
echo "═══════════════════════════════════════"

# 1) dependências — o Zest instala SOZINHO o que falta (sudo, ou su no Debian cru)
NEED=()
command -v zsh >/dev/null 2>&1 || NEED+=(zsh)
command -v git >/dev/null 2>&1 || NEED+=(git)
command -v curl >/dev/null 2>&1 || NEED+=(curl)
if [[ $WITH_PLUGINS == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  command -v python3 >/dev/null 2>&1 || NEED+=(python3)
fi

if (( ${#NEED[@]} )); then
  PM=""; PM_INSTALL=""
  if   command -v apt-get >/dev/null 2>&1; then PM="apt";    PM_INSTALL="apt-get install -y"
  elif command -v dnf     >/dev/null 2>&1; then PM="dnf";    PM_INSTALL="dnf install -y"
  elif command -v pacman  >/dev/null 2>&1; then PM="pacman"; PM_INSTALL="pacman -Sy --noconfirm"
  elif command -v zypper  >/dev/null 2>&1; then PM="zypper"; PM_INSTALL="zypper install -y"
  elif command -v apk     >/dev/null 2>&1; then PM="apk";    PM_INSTALL="apk add"
  fi

  if [[ -z "$PM" ]]; then
    echo "❌ Faltam: ${NEED[*]} — e não encontrei apt/dnf/pacman/zypper/apk para instalá-los."
    echo "   Instale manualmente e rode este instalador de novo."
    exit 1
  fi

  echo "📦 Faltam dependências: ${NEED[*]}"
  echo "   Instalando com $PM — pode pedir sua senha (sudo) ou a do root (su)…"
  if [[ "$PM" == "apt" ]]; then
    if command -v sudo >/dev/null 2>&1; then sudo apt-get update -q || true
    else su -c 'apt-get update -q' || true; fi
  fi
  if command -v sudo >/dev/null 2>&1 && sudo $PM_INSTALL "${NEED[@]}"; then
    echo "✓ dependências instaladas (via sudo)"
  elif su -c "$PM_INSTALL ${NEED[*]}"; then
    echo "✓ dependências instaladas (via su)"
  else
    echo "❌ Não consegui instalar automaticamente. Faça manualmente e rode de novo:"
    echo "   sudo $PM_INSTALL ${NEED[*]}"
    echo "   ou:  su -c '$PM_INSTALL ${NEED[*]}'"
    exit 1
  fi
fi
echo "✓ zsh encontrado: $(zsh --version)"

# 2) Oh My Zsh: instala ANTES de mexer no .zshrc (para ele criar o template com plugins=())
# Créditos: Oh My Zsh é projeto de Robby Russell e comunidade — https://ohmyzsh.com (MIT)
if [[ $WITH_OMZ == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "· Oh My Zsh não encontrado — instalando (sem root, sem trocar seu shell)…"
  # ZSH fixado: o instalador não pode herdar um ZSH de outro shell do usuário
  if ZSH="$HOME/.oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended --keep-zshrc >/dev/null 2>&1; then
    echo "✓ Oh My Zsh instalado em ~/.oh-my-zsh"
  else
    echo "⚠️  download do Oh My Zsh falhou — seguindo em modo standalone (plugins carregados pelo módulo 10)"
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
  [[ -f "$BAK" ]] || cp "$ZSHRC" "$BAK"
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
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions"
    [zsh-history-substring-search]="https://github.com/zsh-users/zsh-history-substring-search"
    [zsh-autopair]="https://github.com/hlissner/zsh-autopair"
  )

  # 6a) Com Oh My Zsh: plugins em custom/plugins + lista plugins=()
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    CUST="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$CUST"
    for p in "${!REPOS[@]}"; do
      if [[ ! -d "$CUST/$p" ]]; then
        git clone --depth 1 -q "${REPOS[$p]}" "$CUST/$p" && echo "✓ plugin clonado: $p"
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
        git clone --depth 1 -q "${REPOS[$p]}" "$PDIR/$p" && echo "✓ plugin standalone: $p"
      fi
    done
  fi
fi

echo "═══════════════════════════════════════"
# 7) shell padrão — se ainda for bash (ou outro), o Zest nunca carrega num terminal novo
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
echo "   Ferramentas (opcional, sem root):  zest add fzf bat eza ripgrep fd delta lazygit duf jq yq direnv tldr zoxide atuin mise"
