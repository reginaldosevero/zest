#!/usr/bin/env bash
# zest :: lib/distro — detecção de gerenciador de pacotes
# Nenhum hardcode de distro: quem decide é o que está instalado na máquina.
#
# Usado por:
#   install.sh          → instalar dependências que faltam (zsh, git, curl…)
#   install-tool.sh     → v0.2: preferir pacote nativo ao binário de release
#   46-system.zsh (zsh) → sysclean/updateall (versão zsh em modules/06-pm.zsh)
#
# Biblioteca: não altera opções globais do shell (por isso não há 'set -u' aqui).
# Quem faz 'source' decide o próprio regime de erro — install.sh usa
# 'set -euo pipefail' e install-tool.sh usa 'set -u' antes de nos carregar.

# zest_pm_detect — primeiro gerenciador encontrado. Sem "distro X é Y":
# só olha o que existe no PATH.
zest_pm_detect() {
  local pm
  for pm in apt-get dnf pacman zypper apk; do
    command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return 0; }
  done
  return 1
}

# zest_pm_run <pm> <args...> — roda o comando do PM
# root já é root: não chama sudo (que pode não existir) nem su (que pede
# senha e falha em container sem PAM). É o caso comum em VM/container.
# Usa 'id -u' (builtin do bash) em vez de EUID: em container, o PATH pode
# não ter o 'id' e um 'id' falso no PATH enganaria a checagem.
zest_pm_run() {
  local pm="$1"; shift
  if [[ "$(id -u)" == "0" ]]; then
    "$pm" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$pm" "$@"
  elif command -v su >/dev/null 2>&1; then
    su -c "$pm $*"
  else
    echo "❌ Sem sudo e sem su — rode manualmente: $pm $*" >&2
    return 1
  fi
}

# zest_pm_install <pm> <pacote...> — instala (assume índice já atualizado:
# quem decide quando atualizar é o chamador, para não repetir a cada pacote)
zest_pm_install() {
  local pm="$1"; shift
  case "$pm" in
    apt-get) zest_pm_run apt-get install -y "$@" ;;
    dnf)     zest_pm_run dnf install -y "$@" ;;
    pacman)  zest_pm_run pacman -Sy --noconfirm "$@" ;;
    zypper)  zest_pm_run zypper --non-interactive install "$@" ;;
    apk)     zest_pm_run apk add "$@" ;;
    *) echo "❌ Gerenciador desconhecido: $pm" >&2; return 1 ;;
  esac
}

# zest_pm_update <pm> — só atualiza a lista de pacotes, não instala nada
zest_pm_update() {
  case "$1" in
    apt-get) zest_pm_run apt-get update -q ;;
    dnf)     zest_pm_run dnf makecache ;;
    pacman)  zest_pm_run pacman -Sy ;;
    zypper)  zest_pm_run zypper --non-interactive refresh ;;
    apk)     zest_pm_run apk update ;;
    *) return 1 ;;
  esac
}

# zest_pm_upgrade <pm> — atualiza os pacotes instalados
zest_pm_upgrade() {
  case "$1" in
    apt-get) zest_pm_run apt-get upgrade -y ;;
    dnf)     zest_pm_run dnf upgrade -y ;;
    pacman)  zest_pm_run pacman -Syu --noconfirm ;;
    zypper)  zest_pm_run zypper --non-interactive update ;;
    apk)     zest_pm_run apk upgrade ;;
    *) return 1 ;;
  esac
}

# zest_pm_autoremove <pm> — tira pacotes órfãos
# pacman não tem flag de autoremove: a lista vem de 'pacman -Qdtq' (pacotes
# instalados como dependência e ninguém mais usando).
zest_pm_autoremove() {
  case "$1" in
    apt-get) zest_pm_run apt-get autoremove -y ;;
    dnf)     zest_pm_run dnf autoremove -y ;;
    pacman)  local orphans
             orphans=$(pacman -Qdtq 2>/dev/null)
             if [[ -n "$orphans" ]]; then
               # sem aspas de propósito: um pacote por linha vira um argumento
               zest_pm_run pacman -Rns --noconfirm $orphans
             else
               echo "   nenhum pacote órfão"
             fi ;;
    # apk já remove dependências não usadas junto com o pacote; zypper não tem
    # equivalente seguro — pular é melhor que sair removendo coisa errada
    zypper|apk) echo "   $1 não tem autoremove — pulando" ; return 0 ;;
    *) return 1 ;;
  esac
}

# zest_pm_clean <pm> — limpa cache de pacotes baixados
zest_pm_clean() {
  case "$1" in
    apt-get) zest_pm_run apt-get autoclean ;;
    dnf)     zest_pm_run dnf clean all ;;
    pacman)  zest_pm_run pacman -Sc --noconfirm ;;
    zypper)  zest_pm_run zypper clean ;;
    apk)     zest_pm_run apk cache clean ;;
    *) return 1 ;;
  esac
}

# zest_pm_has <pm> <pacote> — o pacote EXISTE nessa distro?
# Consulta somente leitura: nenhuma senha é pedida aqui. É o que evita a
# situação chata de pedir sudo para descobrir que o pacote não existe.
zest_pm_has() {
  case "$1" in
    # apt-cache traduz o rótulo ("Candidato"/"Candidate") conforme o locale, e
    # pacote inexistente não imprime nada. Força C locale no apt-cache e aceita
    # só "Candidate: <versão>" — nunca "(none)".
    apt-get) LC_ALL=C apt-cache policy "$2" 2>/dev/null \
             | grep -Eq '^[[:space:]]+Candidate: +[^ (]' ;;
    dnf)     dnf -q list available "$2" 2>/dev/null | grep -q "^$2\." ;;
    pacman)  pacman -Si "$2" >/dev/null 2>&1 ;;
    zypper)  zypper info -t package "$2" >/dev/null 2>&1 ;;
    apk)     apk info -e "$2" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# zest_pkg <tool> <pm> — nome do pacote naquela distro
# REGRA: só devolve nome quando o PACOTE instala o binário com o nome que o
# Zest espera. Se o pacote instala outro nome, devolvemos vazio (return 1) e o
# instalador vai direto para o binário de release — que sempre chega com o nome
# certo e sem root. Instalar o pacote "quase certo" deixava um binário órfão
# (ex.: no apt, `bat` instala /usr/bin/batcat e `fd-find` instala /usr/bin/fdfind
# → os aliases do Zest apontariam para um comando inexistente).
# Casos conhecidos e já tratados:
#   yq        → o `yq` do apt é o wrapper Python do jq, não o yq Go do Zest
#   bat, fd   → nomes de binário divergentes no apt (batcat / fdfind)
#   tldr      → o pacote é tealdeer, e aí o binário É tldr → ok
zest_pkg() {
  local tool="$1" pm="$2"
  case "$tool" in
    yq)   return 1 ;;
    bat)  [[ "$pm" == apt-get ]] && return 1
          echo bat; return 0 ;;
    fd)   [[ "$pm" == apt-get ]] && return 1
          case "$pm" in dnf) echo fd-find ;; *) echo fd ;; esac; return 0 ;;
    # delta: no apt o pacote é git-delta (instala /usr/bin/delta — conferido na
    # listagem de arquivos do pacote). No Fedora não existe git-delta/rust-delta,
    # então devolvemos vazio e o binário de release assume.
    delta) case "$pm" in apt-get|pacman) echo git-delta; return 0 ;; esac
          return 1 ;;
    tldr) echo tealdeer; return 0 ;;
    fzf|ripgrep|eza|lazygit|duf|jq|direnv|zoxide|atuin|mise)
      echo "$tool"; return 0 ;;
    thefuck) echo thefuck; return 0 ;;
  esac
  return 1
}
