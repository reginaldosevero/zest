# zest :: welcome — mensagem de boas-vindas (ZEST_QUIET=1 desativa)
if [[ -z "$ZEST_QUIET" ]]; then
  echo ""
  echo "  🚀 $(date '+%A, %d/%m/%Y — %H:%M')"
  echo "  💡 Ctrl+R histórico (fzf) | Ctrl+T arquivos | Alt+C diretórios"
  echo "     z  → cd inteligente (Zoxide) | fuck → corrige último comando"
  echo "     ajuda → lista TODOS os comandos | weather · news · sysinfo"
  echo ""
fi
# fastfetch 2>/dev/null   # descomente para ver o resumo do sistema a cada terminal
