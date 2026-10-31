# zest :: 22-prompt — prompt com status do git, sem framework
# O Zest não exige Oh My Zsh, mas uma máquina zerada recebe só o "%m%# " cru do
# zsh — então o prompt visual precisa vir daqui.
#
# Regras:
#   ZEST_PROMPT=zest|compact|plain  força um estilo
#   ZEST_PROMPT=off                 nunca mexe no prompt
#   sem ZEST_PROMPT                 só age se ninguém trocou o prompt antes
#                                   (não passa por cima de Oh My Zsh, starship,
#                                    powerlevel10k nem do PS1 que a pessoa já tinha)
#
# O estilo escolhido na instalação fica gravado em $ZEST_HOME/prompt.

# _zest-prompt-estilo — o que usar hoje (zest | compact | plain | off)
# Ordem de precedência:
#   1. ZEST_PROMPT (exportada pelo .zshrc via `zest prompt`) — quem pediu
#   2. $ZEST_HOME/prompt (gravado na instalação)
#   3. PS1 pré-existente → off (respeita omz/starship/p10k)
#   4. zsh cru → zest
_zest-prompt-estilo() {
  local arq="${ZEST_HOME:-$HOME/.config/zest}/prompt"
  if [[ -n "${ZEST_PROMPT:-}" ]]; then
    print -r -- "$ZEST_PROMPT"
  elif [[ -f "$arq" ]]; then
    local escolha
    read -r escolha <"$arq"
    print -r -- "${escolha:-off}"
  elif [[ -n "$PS1" && "$PS1" != '%m%# ' ]]; then
    print -r -- off        # alguém já customizou o prompt (omz, starship, p10k)
  else
    print -r -- zest       # zsh cru: dá para customizar sem incomodar ninguém
  fi
}

_ZEST_ESTILO=$(_zest-prompt-estilo)

if [[ "$_ZEST_ESTILO" != off ]]; then
  # git: branch + estado da árvore com vcs_info (nativo do zsh, sem subshell por prompt)
  autoload -Uz vcs_info add-zsh-hook
  zstyle ':vcs_info:*' enable git hg
  zstyle ':vcs_info:*' check-for-changes true
  zstyle ':vcs_info:*' unstagedstr '●'
  zstyle ':vcs_info:*' stagedstr '✚'
  zstyle ':vcs_info:*' formats ' %F{cyan}‹%b%u%s›%f'
  zstyle ':vcs_info:*' actionformats ' %F{cyan}‹%b|%a›%f'
  _zest-vcs-info() { vcs_info }
  add-zsh-hook precmd _zest-vcs-info

  setopt PROMPT_SUBST

  # %n@%m usuário@máquina · %~ caminho com ~ · %(!.#.❯) # para root
  # %(?.A.B)  A quando o último comando retornou 0
  case "$_ZEST_ESTILO" in
    plain)
      PROMPT='%n@%m %~%(?.:. ✗)%# '
      RPROMPT=''
      ;;
    compact)
      PROMPT='%F{blue}%1~%f${vcs_info_msg_0_} %(?.:%F{red}✗ )%(!.#.❯)%f '
      RPROMPT=''
      ;;
    *)
      # duas linhas, no formato que quem vem do gnzh/agnoster já reconhece
      PROMPT='%F{magenta}╭─%f%n@%m %F{blue}%~%f${vcs_info_msg_0_}%(?.:. %F{red}✗%?%f)
%F{magenta}╰─%f%(?.%F{green}.%F{red})%(!.#.❯)%f '
      RPROMPT='%F{240}%*%f'
      ;;
  esac
fi
unset _ZEST_ESTILO
