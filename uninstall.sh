#!/usr/bin/env bash
# zest :: uninstall — remove o Zest de forma limpa (as ferramentas ficam)
set -uo pipefail
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"

echo "🌶️  Zest — desinstalação"

if [[ -f "$ZSHRC" ]] && grep -q ">>> zest >>>" "$ZSHRC"; then
  TMP="$(mktemp)"
  # remove o bloco marcado (e só ele) — awk em vez de python3: funciona em
  # qualquer distro mínima (Debian slim, Alpine) sem dependências extras
  awk '
    /^# >>> zest >>>$/ { skip = 1; next }
    /^# <<< zest <<<$/ { skip = 0; next }
    skip { next }
    /^[[:space:]]*$/ { blanks++; next }
    { while (blanks > 0) { print ""; blanks-- } print }
  ' "$ZSHRC" > "$TMP" && cat "$TMP" > "$ZSHRC" && rm -f "$TMP"
  echo "OK: bloco do Zest removido do .zshrc (mais nada foi tocado)"
else
  echo "· .zshrc sem bloco do Zest"
fi

rm -rf "$DEST" && echo "✓ módulos removidos de $DEST"
rm -f "$HOME/.local/bin/zest" && echo "✓ comando 'zest' removido"

echo ""
echo "As ferramentas CLI instaladas em ~/.local/bin foram MANTIDAS:"
echo "  fzf zoxide atuin mise jq yq direnv eza rg fd bat delta lazygit duf tldr"
echo "Para removê-las também:  rm -f ~/.local/bin/{fzf,zoxide,atuin,mise,jq,yq,direnv,eza,rg,fd,bat,delta,lazygit,duf,tldr}"
