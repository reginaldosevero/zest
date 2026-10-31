# zest :: 06-pm — detecção de gerenciador de pacotes (zero hardcode de distro)
# Carregado antes de 46-system (sysclean/updateall) e 48-text (spell), que
# precisam saber se a máquina é apt, dnf, pacman, zypper ou apk.
# Versão zsh de lib/distro.sh — os módulos são lidos direto no shell, sem bash.

# _zest-pm-detect — imprime o gerenciador encontrado (apt-get|dnf|pacman|zypper|apk)
_zest-pm-detect() {
  local pm
  for pm in apt-get dnf pacman zypper apk; do
    (( $+commands[$pm] )) && { print -r -- $pm; return 0; }
  done
  return 1
}

# _zest-sudo <comando...> — eleva com sudo, ou su -c no Debian sem sudo
_zest-sudo() {
  if (( $+commands[sudo] )); then
    sudo "$@"
  elif (( $+commands[su] )); then
    su -c "$*"
  else
    print -u2 -- "❌ Sem sudo e sem su — rode manualmente: $*"
    return 1
  fi
}

# _zest-pm-run <pm> <args...>
_zest-pm-run() {
  local pm=$1; shift
  _zest-sudo $pm "$@"
}

# _zest-pm-update <pm> / _zest-pm-upgrade <pm>
_zest-pm-update() {
  case $1 in
    apt-get) _zest-pm-run apt-get update -q ;;
    dnf)     _zest-pm-run dnf makecache ;;
    pacman)  _zest-pm-run pacman -Sy ;;
    zypper)  _zest-pm-run zypper --non-interactive refresh ;;
    apk)     _zest-pm-run apk update ;;
    *) return 1 ;;
  esac
}

_zest-pm-upgrade() {
  case $1 in
    apt-get) _zest-pm-run apt-get upgrade -y ;;
    dnf)     _zest-pm-run dnf upgrade -y ;;
    pacman)  _zest-pm-run pacman -Syu --noconfirm ;;
    zypper)  _zest-pm-run zypper --non-interactive update ;;
    apk)     _zest-pm-run apk upgrade ;;
    *) return 1 ;;
  esac
}

# _zest-pm-autoremove <pm> — remove órfãos
# pacman não tem flag própria: 'pacman -Qdtq' lista o que foi instalado como
# dependência e ninguém usa mais. zypper/apk não têm equivalente seguro → pula.
_zest-pm-autoremove() {
  case $1 in
    apt-get) _zest-pm-run apt-get autoremove -y ;;
    dnf)     _zest-pm-run dnf autoremove -y ;;
    pacman)
      local -a orphans
      orphans=(${(f)"$(pacman -Qdtq 2>/dev/null)"})
      if (( ${#orphans} )); then
        _zest-pm-run pacman -Rns --noconfirm $orphans
      else
        echo "   nenhum pacote órfão"
      fi ;;
    zypper|apk) echo "   $1 não tem autoremove — pulando" ;;
    *) return 1 ;;
  esac
}

# _zest-pm-clean <pm> — limpa cache de pacotes
_zest-pm-clean() {
  case $1 in
    apt-get) _zest-pm-run apt-get autoclean ;;
    dnf)     _zest-pm-run dnf clean all ;;
    pacman)  _zest-pm-run pacman -Sc --noconfirm ;;
    zypper)  _zest-pm-run zypper clean ;;
    apk)     _zest-pm-run apk cache clean ;;
    *) return 1 ;;
  esac
}

# _zest-pm-hint <pacote...> — frase pronta de instalação para mensagens de erro
_zest-pm-hint() {
  local pm=${1:-}
  shift
  case $pm in
    apt-get) print -r -- "sudo apt install $*" ;;
    dnf)     print -r -- "sudo dnf install $*" ;;
    pacman)  print -r -- "sudo pacman -S $*" ;;
    zypper)  print -r -- "sudo zypper install $*" ;;
    apk)     print -r -- "sudo apk add $*" ;;
    *)       print -r -- "use o gerenciador da sua distro para instalar $*" ;;
  esac
}
