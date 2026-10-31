#!/usr/bin/env bash
# zest :: uninstall — remove o Zest de forma limpa
# uso: uninstall.sh [--full]
#   --full   : remove também Oh My Zsh, backups do .zshrc e cache de completion
#              (use com cuidado: apaga tudo que o Zest criou)
#
# SEM --full (padrão):
#   remove o bloco do .zshrc, ~/.config/zest e o comando zest
#   MANTÉM ferramentas em ~/.local/bin (você as quer para outro projeto)
#   MANTÉM backups do .zshrc (por segurança)
set -uo pipefail
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"
FULL=0
for arg in "$@"; do
  case $arg in
    --full) FULL=1 ;;
    *) echo "Uso: uninstall.sh [--full]"; exit 0 ;;
  esac
done

echo "🌶️  Zest — desinstalação"
echo "═══════════════════════════════════════"

# 1) bloco do Zest no .zshrc (sempre removido)
if [[ -f "$ZSHRC" ]] && grep -q ">>> zest >>>" "$ZSHRC"; then
  TMP="$(mktemp)"
  # awk em vez de python3: funciona em qualquer distro mínima
  awk '
    /^# >>> zest >>>$/ { skip = 1; next }
    /^# <<< zest <<<$/ { skip = 0; next }
    skip { next }
    /^[[:space:]]*$/ { blanks++; next }
    { while (blanks > 0) { print ""; blanks-- } print }
  ' "$ZSHRC" > "$TMP" && cat "$TMP" > "$ZSHRC" && rm -f "$TMP"
  echo "✓ bloco do Zest removido do .zshrc"
else
  echo "· .zshrc sem bloco do Zest"
fi

# 1b) bloco do Zest no .bashrc (quando o shell padrão ainda era bash)
if [[ -f "$HOME/.bashrc" ]] && grep -q ">>> zest >>>" "$HOME/.bashrc"; then
  TMP="$(mktemp)"
  awk '
    /^# >>> zest >>>$/ { skip = 1; next }
    /^# <<< zest <<<$/ { skip = 0; next }
    skip { next }
    /^[[:space:]]*$/ { blanks++; next }
    { while (blanks > 0) { print ""; blanks-- } print }
  ' "$HOME/.bashrc" > "$TMP" && cat "$TMP" > "$HOME/.bashrc" && rm -f "$TMP"
  echo "✓ bloco do Zest removido do .bashrc"
fi

# 2) diretório de módulos (sempre removido)
if [[ -d "$DEST" ]]; then
  rm -rf "$DEST" && echo "✓ módulos removidos de $DEST"
fi

# 3) comando zest (sempre removido)
if [[ -f "$HOME/.local/bin/zest" ]]; then
  rm -f "$HOME/.local/bin/zest" && echo "✓ comando 'zest' removido"
fi

# 4) Oh My Zsh (só com --full)
if (( FULL == 1 )) && [[ -d "$HOME/.oh-my-zsh" ]]; then
  rm -rf "$HOME/.oh-my-zsh" && echo "✓ Oh My Zsh removido"
fi

# 5) backups do .zshrc criados pelo instalador (só com --full)
if (( FULL == 1 )); then
  count=0
  for bak in "$HOME"/.zshrc.zest-bak-*; do
    [[ -f "$bak" ]] || continue
    rm -f "$bak" && echo "✓ backup removido: $(basename "$bak")"
    count=$((count + 1))
  done
  (( count == 0 )) && echo "· nenhum backup do Zest encontrado"
fi

# 6) cache de completion (só com --full)
if (( FULL == 1 )); then
  count=0
  for f in "$HOME"/.zcompdump-* "$HOME"/.cache/zest-zcompdump*; do
    [[ -f "$f" ]] || continue
    rm -f "$f" && echo "✓ cache removido: $(basename "$f")"
    count=$((count + 1))
  done
  (( count == 0 )) && echo "· nenhum cache de completion do Zest encontrado"
fi

echo ""
echo "═══════════════════════════════════════"
if (( FULL == 0 )); then
  echo "✅ Modo padrão — Zest removido, ferramentas mantidas."
  echo "   Para remover TAMBOÉM Oh My Zsh, backups e cache:"
  echo "     bash uninstall.sh --full"
elif (( FULL == 1 )); then
  echo "✅ Modo completo — tudo removido (Oh My Zsh, backups, cache)."
  echo "   Ferramentas em ~/.local/bin (bat, fzf, rg...) NÃO foram tocadas."
  echo "   Para apagá-las também:"
  echo "     rm -f ~/.local/bin/{fzf,zoxide,atuin,mise,jq,yq,direnv,eza,rg,fd,bat,delta,lazygit,duf,tldr}"
  echo ""
  echo "   Pacotes instalados com 'zest add --prefer-pm' são do SISTEMA e continuam"
  echo "   aí de propósito: remover pacote da distro é decisão sua, não do Zest."
  echo "   Para remover um deles, use o gerenciador da distro (ex.: dnf remove jq)."
fi
