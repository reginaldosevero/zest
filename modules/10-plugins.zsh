# zest :: plugins — plugins zsh em modo STANDALONE (sem Oh My Zsh)
# No modo Oh My Zsh, o install.sh coloca os plugins na lista plugins=() e este
# módulo não faz nada. Aqui eles são carregados diretamente — funciona com
# zsh puro ou qualquer framework (zinit, antidote, etc.), pois são só scripts.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  ZP="${ZEST_HOME:-$HOME/.config/zest}/plugins"
  if [[ -d "$ZP" ]]; then
    # completions precisa entrar no fpath ANTES do compinit
    [[ -d "$ZP/zsh-completions" ]] && fpath=("$ZP/zsh-completions" $fpath)
    autoload -Uz compinit
    mkdir -p "$HOME/.cache"
    compinit -d "$HOME/.cache/zest-zcompdump" 2>/dev/null
    # ordem importa: syntax-highlighting antes de history-substring-search
    [ -f "$ZP/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$ZP/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [ -f "$ZP/zsh-autopair/autopair.zsh" ] && source "$ZP/zsh-autopair/autopair.zsh"
    [ -f "$ZP/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && source "$ZP/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [ -f "$ZP/zsh-history-substring-search/zsh-history-substring-search.zsh" ] && source "$ZP/zsh-history-substring-search/zsh-history-substring-search.zsh"
  fi
fi
