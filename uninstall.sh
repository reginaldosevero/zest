#!/usr/bin/env bash
# zest :: uninstall — remove o Zest de forma limpa (as ferramentas ficam)
set -uo pipefail
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"

echo "🌶️  Zest — desinstalação"

if [[ -f "$ZSHRC" ]] && grep -q ">>> zest >>>" "$ZSHRC"; then
  python3 - "$ZSHRC" <<'PYEOF'
import sys
path = sys.argv[1]
src = open(path).read()
if ">>> zest >>>" in src and "<<< zest <<<" in src:
    pre, _, rest = src.partition("# >>> zest >>>")
    _, _, pos = rest.partition("# <<< zest <<<")
    open(path, "w").write(pre.rstrip("\n") + "\n" + pos.lstrip("\n"))
    print("✓ bloco do Zest removido do .zshrc (mais nada foi tocado)")
PYEOF
else
  echo "· .zshrc sem bloco do Zest"
fi

rm -rf "$DEST" && echo "✓ módulos removidos de $DEST"
rm -f "$HOME/.local/bin/zest" && echo "✓ comando 'zest' removido"

echo ""
echo "As ferramentas CLI instaladas em ~/.local/bin foram MANTIDAS:"
echo "  fzf zoxide atuin mise jq yq direnv eza rg fd bat delta lazygit duf tldr"
echo "Para removê-las também:  rm -f ~/.local/bin/{fzf,zoxide,atuin,mise,jq,yq,direnv,eza,rg,fd,bat,delta,lazygit,duf,tldr}"
