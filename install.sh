#!/usr/bin/env bash
# zest :: install — instala o Zest sem root, sem destruir nada
# princípios: aditivo (nunca remove), idempotente (rodar 2x = igual), reversível
set -euo pipefail

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

# 1) zsh presente?
if ! command -v zsh >/dev/null 2>&1; then
  echo "❌ zsh não encontrado. Instale com um destes (precisa de sudo):"
  echo "   Debian/Ubuntu/Mint : sudo apt install zsh"
  echo "   Fedora             : sudo dnf install zsh"
  echo "   Arch               : sudo pacman -S zsh"
  echo "   openSUSE           : sudo zypper install zsh"
  echo "   Alpine             : sudo apk add zsh"
  exit 1
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
ln -sf "$REPO_DIR/bin/zest" "$HOME/.local/bin/zest"
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
    python3 - "$ZSHRC" "${!REPOS[@]}" <<'PYEOF'
import re, sys
path, want = sys.argv[1], sys.argv[2:]
src = open(path).read()
m = re.search(r'plugins=\(([^)]*)\)', src)
if not m:
    print("· nenhuma lista plugins=() encontrada — pulei")
    sys.exit(0)
have = set(re.findall(r'[\w-]+', m.group(1)))
add = [w for w in want if w not in have]
if add:
    bloco = m.group(0)[:-1] + '  ' + ' '.join(add) + '\n)'
    src = src[:m.start()] + bloco + src[m.end():]
    open(path, 'w').write(src)
    print("✓ plugins acrescentados à lista:", ' '.join(add))
else:
    print("✓ todos os plugins já estão na lista")
PYEOF
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
echo "✅ Pronto! Ative com:  source ~/.zshrc   (ou abra um terminal novo)"
echo "   Diagnóstico:        zest doctor"
echo "   Ferramentas (opcional, sem root):  zest add fzf bat eza ripgrep fd delta lazygit duf jq yq direnv tldr zoxide atuin mise"
