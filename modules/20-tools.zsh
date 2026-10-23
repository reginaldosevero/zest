# zest :: 20-tools — módulo do Zest (extraído e testado na prática)
# ------------------------------------------------------------
#  VARIÁVEIS DE AMBIENTE DAS NOVAS FERRAMENTAS
# ------------------------------------------------------------
export DELTA_PAGER='less -R'                 # delta (diff do git)
export ATUIN_NOBIND="true"                   # atuin não captura Ctrl+R (fica com o fzf)
export MISE_DATA_DIR="$HOME/.local/share/mise"
export DIRENV_LOG_FORMAT=""                  # direnv silencioso
export BAT_THEME="Dracula"                   # bat (cat melhorado)
export EZA_ICONS_AUTO="true"                 # eza (ls melhorado)

# ------------------------------------------------------------
#  ATUIN — histórico de shell sincronizado/consultável
# ------------------------------------------------------------
[ -f "$HOME/.atuin/bin/env" ] && . "$HOME/.atuin/bin/env"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"

# ------------------------------------------------------------
#  MISE — gerenciador de versões (node, python, go, rust...)
# ------------------------------------------------------------
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# ------------------------------------------------------------
#  ZOXIDE — cd inteligente que aprende seus diretórios
# ------------------------------------------------------------
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# ------------------------------------------------------------
#  DIRENV — variáveis de ambiente por projeto (.envrc)
# ------------------------------------------------------------
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# ------------------------------------------------------------
#  GIT DELTA — diff melhorado (config global, uma única vez)
# ------------------------------------------------------------
if command -v delta >/dev/null 2>&1; then
  export GIT_PAGER='delta'
  if [[ "$(git config --global core.pager 2>/dev/null)" != "delta" ]]; then
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default
  fi
fi

# ------------------------------------------------------------
#  FZF — busca fuzzy (Ctrl+R histórico, Ctrl+T arquivos, Alt+C dirs)
# ------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --margin=1 --padding=1"
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# ------------------------------------------------------------
#  THEFUCK — fuck corrige o último comando digitado errado
#  (carregamento preguiçoso: não pesa o startup do shell)
# ------------------------------------------------------------
if command -v thefuck >/dev/null 2>&1; then
  fuck() {
    unfunction fuck
    eval "$(thefuck --alias)"
    fuck "$@"
  }
fi

# ------------------------------------------------------------
