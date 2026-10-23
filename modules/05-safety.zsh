# zest :: 05-safety — módulo do Zest (extraído e testado na prática)
#  PERFORMANCE
# ------------------------------------------------------------
mkdir -p ~/.zsh/cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache
DIRSTACKSIZE=20

# ------------------------------------------------------------
#  SEGURANÇA
# ------------------------------------------------------------
# NO_CLOBBER protege '>' de sobrescrever arquivos existentes.
# ATENÇÃO (comportamento do zsh, diferente do bash): com noclobber,
# '>>' só funciona em arquivos que JÁ EXISTEM — use '>>!' para
# criar+anexar, e '>|' para sobrescrever de propósito.
setopt NO_CLOBBER
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ------------------------------------------------------------
