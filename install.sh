#!/usr/bin/env bash
# zest :: install — instala o Zest sem root, sem destruir nada
# princípios: aditivo (nunca remove), idempotente (rodar 2x = igual), reversível
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"
WITH_PLUGINS=0
[[ "${1:-}" == "--with-plugins" ]] && WITH_PLUGINS=1

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

# 2) copia módulos e lib (idempotente)
mkdir -p "$DEST"
cp -r "$REPO_DIR/modules" "$REPO_DIR/lib" "$DEST/" 2>/dev/null || true
mkdir -p "$DEST/modules" "$DEST/lib"
cp "$REPO_DIR"/modules/*.zsh "$DEST/modules/"
[[ -d "$REPO_DIR/lib" ]] && cp -r "$REPO_DIR"/lib/* "$DEST/lib/" 2>/dev/null || true
chmod +x "$REPO_DIR/bin/zest"
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_DIR/bin/zest" "$HOME/.local/bin/zest"
echo "✓ módulos em $DEST"

# 3) backup do .zshrc (uma vez por dia, sem acumular)
if [[ -f "$ZSHRC" ]]; then
  BAK="$ZSHRC.zest-bak-$(date +%Y%m%d)"
  [[ -f "$BAK" ]] || cp "$ZSHRC" "$BAK"
  echo "✓ backup: $BAK"
fi

# 4) bloco marcado no .zshrc (nunca duplica)
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

# 5) plugins do Oh My Zsh (opcional, só com --with-plugins)
if [[ $WITH_PLUGINS == 1 ]]; then
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    CUST="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$CUST"
    declare -A REPOS=(
      [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
      [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
      [zsh-completions]="https://github.com/zsh-users/zsh-completions"
      [zsh-history-substring-search]="https://github.com/zsh-users/zsh-history-substring-search"
      [zsh-autopair]="https://github.com/hlissner/zsh-autopair"
    )
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
  else
    echo "· Oh My Zsh não encontrado — plugins pulados (os módulos funcionam sem ele)"
  fi
fi

echo "═══════════════════════════════════════"
echo "✅ Pronto! Ative com:  source ~/.zshrc   (ou abra um terminal novo)"
echo "   Diagnóstico:        zest doctor"
echo "   Ferramentas (opcional, sem root):  zest add fzf bat eza ripgrep fd delta lazygit duf jq yq direnv tldr zoxide atuin mise"
