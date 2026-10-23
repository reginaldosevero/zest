# zest :: keys — busca de histórico por substring (setas ↑/↓ com prefixo)
# Só liga se o plugin zsh-history-substring-search estiver carregado (Oh My Zsh)
if (( $+functions[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi
