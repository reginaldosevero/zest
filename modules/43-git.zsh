# zest :: 43-git — módulo do Zest (extraído e testado na prática)
#  ALIASES — Git avançado
# ------------------------------------------------------------
# git com mensagem amigável quando você está FORA de um repositório
# (comandos que funcionam em qualquer pasta — init, clone, config... — passam direto)
git() {
  if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    case "$1" in
      init|clone|--version|-v|config|help|-h|"") ;;   # ok fora de repositório
      *)
        echo "❌ Esta pasta não é um projeto git — 'git $*' precisa estar dentro de um."
        echo "   💡 Repositório de testes: cd ~/sync-demo"
        echo "   💡 Para transformar ESTA pasta em projeto: git init"
        return 1
        ;;
    esac
  fi
  command git "$@"
}

alias glog='git log --all --graph --pretty=format:"%C(magenta)%h%Creset -%C(red)%d%Creset %s %C(dim green)(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gdiff='git diff --stat'
alias gshow='git show --stat'
alias gblame='git blame -w'
alias greflog='git reflog'
alias gtags='git tag -l'
alias gremote='git remote -v'
alias gfetch='git fetch --all --prune'
alias gpull='git pull --rebase --autostash'
alias gpushf='git push --force-with-lease'
alias gstashl='git stash list'
alias gworktree='git worktree list'
alias gsub='git submodule update --init --recursive'

gci() { git add -A; echo "Mensagem do commit:"; read msg; git commit -m "$msg"; }
# OBS: 'gpr' colidia com o alias do plugin git do Oh My Zsh (git pull --rebase),
# que é mantido. O gpr abaixo vira função para criar PR no GitHub; o pull rebase
# continua disponível via alias 'gpull' acima.
unalias gpr 2>/dev/null
gpr() { command gh pr create --title "$1" --body "$2" 2>/dev/null || echo "Instale gh CLI: https://cli.github.com"; }
gsync() { git fetch upstream && git checkout main && git merge upstream/main && git push origin main; }
gclean_branches() { git branch --merged | grep -v '\*\|main\|master\|develop' | xargs -n 1 git branch -d; }
gstash() { git stash push -m "$1"; }
gfiles() { git diff --name-only "$1"; }

# ------------------------------------------------------------
