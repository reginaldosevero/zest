#!/usr/bin/env bash
# zest :: install — instala o Zest sem root, sem destruir nada
# princípios: aditivo (nunca remove), idempotente (rodar 2x = igual), reversível
set -euo pipefail

# locale: VMs recém-instaladas podem vir sem UTF-8 (locale C) — os emojis dos
# avisos e o python3 quebram. C.UTF-8 existe em qualquer distro moderna.
if command locale -a 2>/dev/null | grep -qi '^C\.utf8$'; then
  export LANG=C.UTF-8 LC_ALL=C.UTF-8
fi

# Onde estão os arquivos do Zest. Lendo de stdin ("curl … | bash") não há
# BASH_SOURCE, e o instalador precisa de lib/ e modules/ — sem eles a instalação
# não tem como continuar, então a mensagem diz o caminho certo em vez de
# estourar "BASH_SOURCE[0]: unbound variable".
ZEST_SRC="${BASH_SOURCE[0]:-${BASH_SOURCE[1]:-$0}}"
REPO_DIR="$(cd -- "$(dirname -- "$ZEST_SRC")" >/dev/null 2>&1 && pwd)" || REPO_DIR=""
if [[ ! -f "$REPO_DIR/lib/tools.list" && -n "${ZEST_HOME:-}" && -f "$ZEST_HOME/lib/tools.list" ]]; then
  REPO_DIR="$ZEST_HOME"
fi
NEED_SRC_RESOLVE=0
if [[ ! -f "$REPO_DIR/lib/tools.list" ]]; then
  # O script não veio de um checkout (ex.: "curl … | bash"). O download do repo
  # precisa de git OU curl/wget — que podem faltar numa máquina zerada — e
  # instalar pacotes precisa saber o gerenciador da distro. lib/distro.sh mora no
  # repo que ainda não temos, então os wrappers abaixo seguram o bootstrap sozinhos.
  # Assim que o repo chega, o lib/distro.sh real é lido e passa a valer.
  NEED_SRC_RESOLVE=1
fi
# roda o gerenciador com sudo, ou su no Debian cru (container root sem sudo).
# Fora do 'if' de propósito: os wrappers são autossuficientes mesmo se o
# lib/distro.sh do checkout estiver ausente (checkout quebrado).
pm_run() {
  local pm="$1"; shift
  # root já é root: não chama sudo (que pode não existir) nem su (que pede
  # senha e falha em container sem PAM). É o caso comum em VM/container.
  # Usa 'id -u' (builtin do bash, não depende do PATH) em vez de EUID: em
  # container, o PATH pode não ter o 'id' e um 'id' falso no PATH enganaria
  # a checagem.
  if [[ "$(id -u)" == "0" ]]; then
    "$pm" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$pm" "$@"
  elif command -v su >/dev/null 2>&1; then
    su -c "$pm $*"
  else
    echo "❌ Sem sudo e sem su — rode manualmente: $pm $*" >&2; return 1
  fi
}
pm_detect() {
  if declare -F zest_pm_detect >/dev/null 2>&1; then zest_pm_detect
  else
    local pm
    for pm in apt-get dnf pacman zypper apk; do
      command -v "$pm" >/dev/null 2>&1 && { printf '%s\n' "$pm"; return 0; }
    done
    return 1
  fi
}
pm_install() {
  if declare -F zest_pm_install >/dev/null 2>&1; then zest_pm_install "$@"
  else
    local pm="$1"; shift
    case "$pm" in
      apt-get) pm_run apt-get install -y "$@" ;;
      dnf)     pm_run dnf install -y "$@" ;;
      pacman)  pm_run pacman -Sy --noconfirm "$@" ;;
      zypper)  pm_run zypper --non-interactive install "$@" ;;
      apk)     pm_run apk add "$@" ;;
      *) return 1 ;;
    esac
  fi
}
pm_update() {
  if declare -F zest_pm_update >/dev/null 2>&1; then zest_pm_update "$@"
  else
    case "$1" in
      apt-get) pm_run apt-get update -q ;;
      dnf)     pm_run dnf makecache ;;
      pacman)  pm_run pacman -Sy ;;
      zypper)  pm_run zypper --non-interactive refresh ;;
      apk)     pm_run apk update ;;
      *) return 1 ;;
    esac
  fi
}
# pm_hint_install <pm> <pacote...> — imprime a linha pronta para a máquina dele.
# Não-root precisa de sudo; root não (e em container o sudo pode nem existir).
pm_hint_install() {
  local pm="$1"; shift
  local cmd
  case "$pm" in
    apt-get) cmd="$pm install -y $*" ;;
    dnf)     cmd="$pm install -y $*" ;;
    pacman)  cmd="$pm -Sy --noconfirm $*" ;;
    zypper)  cmd="$pm --non-interactive install $*" ;;
    apk)     cmd="$pm add $*" ;;
    *)       cmd="$pm $*" ;;
  esac
  if [[ "$(id -u)" == "0" ]]; then printf '%s' "$cmd"
  else printf 'sudo %s' "$cmd"; fi
}
# detecção de distro (lib/distro.sh) — usada no passo 1 e no install-tool
if [[ -f "$REPO_DIR/lib/distro.sh" ]]; then
  # shellcheck disable=SC1090  # o caminho só é conhecido na execução
  source "$REPO_DIR/lib/distro.sh"
fi
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"
# Oh My Zsh é OPCIONAL mas NÃO é o padrão: o Zest funciona sem ele. Quem
# quiser o Omz passa --with-omz (ou --with-plugins). Sem argumento, o Zest
# instala só o que ele precisa — o Omz é um framework à parte.
WITH_PLUGINS=0
WITH_OMZ=0
WITH_TOOLS=1
for arg in "$@"; do
  case $arg in
    --with-plugins) WITH_PLUGINS=1 ;;
    --with-omz)     WITH_OMZ=1; WITH_PLUGINS=1 ;;   # instala o Oh My Zsh se faltar
    --no-omz)       WITH_OMZ=0; WITH_PLUGINS=0 ;;   # nem plugins: Zest só
    --no-tools)     WITH_TOOLS=0 ;;                   # CI: pula as 17 ferramentas
  esac
done

# Pergunta que funciona até em "curl ... | bash".
#   Nesse modo o stdin É o pipe com o próprio script: um `read` dali engoliria o
#   resto da instalação e nada seria perguntado. Então, quando o stdin não é um
#   terminal, a leitura vai para /dev/tty (o terminal de verdade). Sem terminal
#   nenhum (CI, cron), devolve 1 e quem chama usa o padrão — nunca lê do stdin.
#   O 2>/dev/null vem ANTES do < /dev/tty de propósito: bash aplica as
#   redireções da esquerda para a direita, e num container sem terminal de
#   controle a abertura falha — com a ordem inversa o "No such device or
#   address" aparecia na tela no meio da instalação.
ask() {
  local _resposta
  if [[ -t 0 ]]; then
    IFS= read -r -p "$1" _resposta || return 1
  elif IFS= read -r -p "$1" _resposta 2>/dev/null < /dev/tty; then
    :
  else
    return 1
  fi
  printf '%s' "$_resposta"
}

echo "🌶️  Zest — instalação"
echo "═══════════════════════════════════════"

# 0) escolha do prompt — o que o terminal vai parecer
#   (pergunta quando há terminal de verdade, inclusive via curl|bash; sem
#    terminal — CI — o default é "zest")
mkdir -p "$DEST"
# Quem já tem Oh My Zsh, starship ou powerlevel10k não precisa de prompt novo:
# a 22-prompt.zsh também detecta isso, mas perguntaria à toa.
HAS_PROMPT=0
if [[ -n "${ZSH:-}" || -n "${STARSHIP_SESSION_KEY:-}" || -d "$HOME/.oh-my-zsh" ]] \
   || ps -o comm= 2>/dev/null | grep -q powerlevel10k; then
  HAS_PROMPT=1
fi

# 0b) tema do Oh My Zsh — só se o Omz for ser instalado. O Zest não é o Omz,
#     então o tema só interessa quem optou por --with-omz. Default: gnzh.
ZSH_THEME="gnzh"
if [[ $WITH_OMZ == 1 ]]; then
  echo ""
  echo "🎨 Tema do Oh My Zsh"
  echo "   O Zest instala o Omz e pergunta qual tema usar. Default: gnzh."
  echo ""
  echo "   Temas comuns:"
  echo "     1) gnzh                  ╭─usuário ~/dir ❯  (recomendado, default)"
  echo "     2) agnoster             ~ ❯  (compacto, sem unicode)"
  echo "     3) powerlevel10k        ~ ❯  (muito customizável)"
  echo "     4) spaceship            ~ ❯  (moderno)"
  echo "     5) robbyrussell         ~/dir %  (padrão do Omz)"
  echo "     6) outro                digite o nome de qualquer tema em"
  echo "                              https://github.com/ohmyzsh/ohmyzsh/wiki/themes"
  if _tema=$(ask "   Qual? [1] "); then
    case "${_tema:-1}" in
      2) ZSH_THEME="agnoster" ;;
      3) ZSH_THEME="powerlevel10k" ;;
      4) ZSH_THEME="spaceship" ;;
      5) ZSH_THEME="robbyrussell" ;;
      6) ZSH_THEME="${_tema}" ;;
      *) ZSH_THEME="gnzh" ;;
    esac
  fi
  unset _tema
fi

if [[ -z "${ZEST_PROMPT:-}" && ! -f "$DEST/prompt" && $HAS_PROMPT == 0 ]]; then
  echo ""
  echo "🎨 Prompt do terminal"
  echo "   O Zest não exige Oh My Zsh, então o prompt vem dele mesmo."
  echo ""
  echo "   1) zest     ╭─usuário@máquina ~/dir ❯  com status do git  (recomendado)"
  echo "   2) compact  ~/dir ❯  (uma linha, leve)"
  echo "   3) plain    usuário@máquina ~/dir\$  (sem cor)"
  echo "   4) off      não mexo no prompt (você configura depois)"
  if _escolha=$(ask "   Qual? [1] "); then
    case "${_escolha:-1}" in
      2) echo "compact" > "$DEST/prompt" ;;
      3) echo "plain"   > "$DEST/prompt" ;;
      4) echo "off"     > "$DEST/prompt" ;;
      *) echo "zest"    > "$DEST/prompt" ;;
    esac
  else
    echo "zest" > "$DEST/prompt"
  fi
  unset _escolha
fi

# 1) dependências — o Zest instala SOZINHO o que falta (root: direto; não-root: sudo/su)
#
# Cada dependência só entra na lista quando o fluxo realmente a usa. Cobrar
# tudo sempre derrubava a instalação em container enxuto: sem git e com curl,
# o `NEED+=(git)` parava o usuário com "não encontrei apt/… para instalá-lo"
# quando o tarball do GitHub (curl) já teria bastado.
#
# Se a instalação automática falhar (sem rede, sem permissão, PM inexistente),
# o instalador NÃO aborta: tenta seguir com o que tem e só fala o que fazer
# no final. Um usuário leigo perde menos assim.
NEED=()
command -v zsh >/dev/null 2>&1 || NEED+=(zsh)
# git: necessário para clonar Oh My Zsh e os plugins. Baixar o próprio Zest
# tem alternativa (tarball via curl/wget), então git não é obrigatório.
if [[ $WITH_OMZ == 1 || $WITH_PLUGINS == 1 ]]; then
  command -v git >/dev/null 2>&1 || NEED+=(git)
fi
# um baixador: as receitas de ferramenta e o download do repo aceitam curl OU wget
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  NEED+=(curl)
fi
if [[ $WITH_PLUGINS == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  command -v python3 >/dev/null 2>&1 || NEED+=(python3)
fi

PM=""
if (( ${#NEED[@]} )); then
  PM=$(pm_detect) || PM=""
  if [[ -z "$PM" ]]; then
    echo "⚠️  Faltam: ${NEED[*]} — e não encontrei apt-get/dnf/pacman/zypper/apk."
    echo "   Vou tentar seguir com o que já existe."
  else
    echo "📦 Faltam dependências: ${NEED[*]}"
    echo "   Gerenciador detectado: $PM — pode pedir sua senha (sudo) ou a do root (su)…"
    pm_update "$PM" || true
    if pm_install "$PM" "${NEED[@]}"; then
      echo "✓ dependências instaladas (via $PM)"
    else
      echo "⚠️  A instalação automática falhou — vou tentar seguir com o que já existe."
      echo "   Se for o caso, instale na mão:  $(pm_hint_install "$PM" "${NEED[@]}")"
    fi
  fi
fi

# zsh é a única dependência realmente inegociável: os módulos são código zsh.
# Sem ele o Zest não carrega em lugar nenhum — então a mensagem tem de ser a
# linha exata para a máquina dele (root não usa sudo), e nada de "rode de novo".
if ! command -v zsh >/dev/null 2>&1; then
  echo ""
  echo "❌ O Zest precisa do zsh e ele não está instalado."
  if [[ -n "$PM" ]]; then
    echo "   Rode esta linha e depois rode o instalador outra vez:"
    echo "     $(pm_hint_install "$PM" zsh)"
  else
    echo "   Instale o zsh pelo gerenciador da sua distro e rode de novo:"
    echo "     apt-get install -y zsh    # Debian/Ubuntu"
    echo "     dnf install -y zsh        # Fedora"
    echo "     pacman -Sy --noconfirm zsh  # Arch"
    echo "     zypper install -y zsh     # openSUSE"
    echo "     apk add zsh               # Alpine"
  fi
  exit 1
fi
echo "✓ zsh encontrado: $(zsh --version)"

# 1b) se o script não estava em um checkout, baixa o Zest AGORA (git e curl já
#     existem, ou a instalação acaba com uma mensagem clara).
# Origem configurável — quem mantém um fork aponta para o próprio:
#   ZEST_ORIGIN=https://github.com/eu/zest ./install.sh
# (o nome é ZEST_ORIGIN de propósito: ZEST_REPO já é usado pelo bin/zest como o
#  DIRETÓRIO do repositório, e dividir a variável faria o CLI procurar módulos
#  num caminho "dono/zest".)
ZEST_ORIGIN="${ZEST_ORIGIN:-https://github.com/reginaldosevero/zest}"
# um dispositivo só existe de verdade se abrir: /dev/tty está presente como
# char device em container sem terminal de controle, e '[[ -c ]]' mente lá.
has_tty() { { exec 3</dev/tty; } 2>/dev/null && { exec 3<&-; return 0; }; return 1; }
zest_src_resolve() {
  local dest="$HOME/.zest-src"
  mkdir -p "$dest"
  if command -v git >/dev/null 2>&1; then
    echo "· clonando o Zest em $dest…"
    if git clone --depth 1 -q "$ZEST_ORIGIN.git" "$dest/zest"; then
      REPO_DIR="$dest/zest"
      return 0
    fi
    echo "· clone falhou — tentando o tarball…"
  fi
  # sem git (ou clone falhou): baixa o tarball do branch padrão.
  # curl, wget, python3 (urllib) ou busybox wget — tenta em ordem.
  local url="$ZEST_ORIGIN/archive/refs/heads/master.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    echo "· baixando o Zest em $dest (curl)…"
    curl -fsSL --proto '=https' "$url" -o "$dest/zest.tar.gz" 2>/dev/null || return 1
  elif command -v wget >/dev/null 2>&1; then
    echo "· baixando o Zest em $dest (wget)…"
    wget -q --https-only -O "$dest/zest.tar.gz" "$url" || return 1
  elif command -v python3 >/dev/null 2>&1; then
    echo "· baixando o Zest em $dest (python3)…"
    python3 -c "
import urllib.request, sys
urllib.request.urlretrieve('$url', '$dest/zest.tar.gz')
" 2>/dev/null || return 1
  elif command -v busybox >/dev/null 2>&1; then
    echo "· baixando o Zest em $dest (busybox wget)…"
    busybox wget -q -O "$dest/zest.tar.gz" "$url" 2>/dev/null || return 1
  else
    return 1
  fi
  if ! tar xzf "$dest/zest.tar.gz" -C "$dest" 2>/dev/null; then
    rm -f "$dest/zest.tar.gz"
    # tar xzf precisa de gzip: sem ele o erro é esse, e não "falta git/curl".
    command -v gzip >/dev/null 2>&1 || echo "   · falta o gzip (o tar dele precisa para descompactar)" >&2
    return 1
  fi
  rm -f "$dest/zest.tar.gz"
  REPO_DIR=$(find "$dest" -maxdepth 1 -mindepth 1 -name 'zest-*' -type d -print -quit)
  [[ -n "$REPO_DIR" ]]
}
if [[ "$NEED_SRC_RESOLVE" == 1 ]]; then
  if ! zest_src_resolve || [[ ! -f "$REPO_DIR/lib/tools.list" ]]; then
    echo ""
    echo "❌ Não tenho como baixar o Zest de $ZEST_ORIGIN."
    echo "   Precisa de um deles: git · curl · wget · python3 · busybox wget"
    echo ""
    echo "   Se tem um deles, instale o Zest assim:"
    echo "     git clone $ZEST_ORIGIN.git && cd zest && ./install.sh"
    echo "     # ou baixe o tarball do navegador (botão Code → Download ZIP)"
    echo ""
    echo "   Se não tem nenhum, baixe o ZIP pela web:"
    echo "     https://github.com/reginaldosevero/zest/archive/refs/heads/master.zip"
    echo "   (abre no navegador, descompacta e roda ./install.sh de dentro)"
    exit 1
  fi
  # agora que o repo chegou, o lib/distro.sh real passa a valer
  # shellcheck disable=SC1091
  source "$REPO_DIR/lib/distro.sh"
  echo "✓ fontes do Zest em $REPO_DIR"
fi

# 2) Oh My Zsh: instala ANTES de mexer no .zshrc (para ele criar o template com plugins=())
# Créditos: Oh My Zsh é projeto de Robby Russell e comunidade — https://ohmyzsh.com (MIT)
if [[ $WITH_OMZ == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "· Oh My Zsh não encontrado — instalando por clone (sem executar script remoto)…"
  # clone em vez de "curl | sh": nenhum código remoto é executado às cegas.
  # Créditos: Oh My Zsh é projeto de Robby Russell e comunidade — https://ohmyzsh.com (MIT)
  # Obs.: o upstream não publica tags/releases — só o branch master. Clonamos
  # com --single-branch e registramos o commit SHA exato em .zest-omz-pin para
  # auditoria/reprodutibilidade (mesmo espírito dos plugins pinados por tag).
  if git clone --depth 1 --single-branch --branch master -q \
       https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" 2>/dev/null; then
    # registra o commit efetivamente instalado (auditoria posterior / rollback)
    ( cd "$HOME/.oh-my-zsh" && git rev-parse HEAD >"$HOME/.oh-my-zsh/.zest-omz-pin" ) 2>/dev/null || true
    # mesmo comportamento do instalador oficial: .zshrc nasce do template
    if [[ ! -f "$ZSHRC" ]]; then
      cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
      echo "✓ .zshrc criado a partir do template do Oh My Zsh"
    fi
    omz_sha=$(cat "$HOME/.oh-my-zsh/.zest-omz-pin" 2>/dev/null | cut -c1-7)
    echo "✓ Oh My Zsh instalado em ~/.oh-my-zsh (commit ${omz_sha:-?})"
  else
    echo "⚠️  clone do Oh My Zsh falhou — seguindo em modo standalone (plugins carregados pelo módulo 10)"
  fi
fi

# 2b) tema do Oh My Zsh — o template nasce com ZSH_THEME="robbyrussell".
#     O Zest pergunta qual tema na instalação (padrão: gnzh) e escreve no .zshrc.
#     Qualquer nome da wiki do Omz é aceito: o tema é carregado pelo próprio
#     Omz, o Zest só grava a linha certa.
if [[ $WITH_OMZ == 1 && -f "$ZSHRC" ]]; then
  if grep -q "^ZSH_THEME=" "$ZSHRC"; then
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$ZSH_THEME\"/" "$ZSHRC"
    echo "✓ tema do Oh My Zsh: $ZSH_THEME"
  elif ! grep -q "^# ZSH_THEME=" "$ZSHRC"; then
    # template antigo: insere a linha perto do topo
    sed -i "1a ZSH_THEME=\"$ZSH_THEME\"" "$ZSHRC"
    echo "✓ tema do Oh My Zsh: $ZSH_THEME"
  fi
fi

# 3) copia módulos e lib (idempotente)
mkdir -p "$DEST"
cp -r "$REPO_DIR/modules" "$REPO_DIR/lib" "$DEST/" 2>/dev/null || true
mkdir -p "$DEST/modules" "$DEST/lib"
cp "$REPO_DIR"/modules/*.zsh "$DEST/modules/"
[[ -d "$REPO_DIR/lib" ]] && cp -r "$REPO_DIR"/lib/* "$DEST/lib/" 2>/dev/null || true
# O +x vai no ARQUIVO COPIADO, não no do clone: o instalador não tem nada a
# mudar no repositório de origem, e um clone somente-leitura (mount de Docker,
# arquivo compactado, outro usuário) quebrava a instalação aqui com
# "Read-only file system".
# Escrever por tmp+mv também evita "Text file busy" ao rodar o instalador de
# novo com o 'zest' em execução (cp não sobrescreve um executável vivo).
mkdir -p "$HOME/.local/bin"
cp "$REPO_DIR/bin/zest" "$HOME/.local/bin/.zest.tmp.$$"   # cópia (não symlink): sobrevive se a pasta do clone for apagada
chmod +x "$HOME/.local/bin/.zest.tmp.$$"
mv -f "$HOME/.local/bin/.zest.tmp.$$" "$HOME/.local/bin/zest"
echo "✓ comando 'zest' em $HOME/.local/bin"
echo "✓ módulos em $DEST"

# 4) backup do .zshrc (uma vez por dia, sem acumular)
if [[ -f "$ZSHRC" ]]; then
  BAK="$ZSHRC.zest-bak-$(date +%Y%m%d)"
  # -p preserva permissões: um .zshrc 600 (com tokens) não vira backup 644
  [[ -f "$BAK" ]] || cp -p "$ZSHRC" "$BAK"
  echo "✓ backup: $BAK"
fi

# 4b) limpa referências órfãs no .zshrc — um framework que já foi desinstalado
#     (Oh My Zsh, Starship, zinit…) deixa a linha 'source $ZSH/oh-my-zsh.sh' no
#     arquivo, e o terminal quebra todo dia com "arquivo ou diretório inexistente".
#     O Zest não pode mandar o usuário abrir o .zshrc na mão: ele varre sozinho
#     e comenta as linhas cujo alvo não existe mais. Nunca apaga nada: só
#     comenta, e o conteúdo do usuário continua intacto.
#     Biblioteca em lib/sweep.sh — também pode ser usada por outros scripts.
for _s in "$REPO_DIR/lib/sweep.sh" "${ZEST_HOME:-$HOME/.config/zest}/lib/sweep.sh"; do
  [[ -f "$_s" ]] && source "$_s" && break
done
zest_sweep_orphans "$ZSHRC"

# 5) bloco marcado no .zshrc (nunca duplica)
if grep -q ">>> zest >>>" "$ZSHRC" 2>/dev/null; then
  echo "✓ .zshrc já carrega o Zest (nada duplicado)"
else
  cat >> "$ZSHRC" <<'EOF'

# >>> zest >>>
# Zest 🌶️ — o tempero do seu terminal (open source, MIT)
# Remoção limpa: rode o uninstall.sh do repositório
export ZEST_HOME="$HOME/.config/zest"
for _zmod in "$ZEST_HOME"/modules/*.zsh(N); do source "$_zmod"; done
unset _zmod
# <<< zest <<<
EOF
  echo "✓ bloco acrescentado ao final do $ZSHRC (nada do que já existia foi alterado)"
fi

# 6) plugins do zsh (opcional, com --with-plugins)
if [[ $WITH_PLUGINS == 1 ]]; then
  declare -A REPOS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions v0.7.1"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting 0.8.0"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions 0.36.0"
    [zsh-history-substring-search]="https://github.com/zsh-users/zsh-history-substring-search v1.1.0"
    [zsh-autopair]="https://github.com/hlissner/zsh-autopair v1.0"
  )

  # 6a) Com Oh My Zsh: plugins em custom/plugins + lista plugins=()
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    CUST="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$CUST"
    for p in "${!REPOS[@]}"; do
      if [[ ! -d "$CUST/$p" ]]; then
        read -r _url _ref <<< "${REPOS[$p]}"
        git clone --depth 1 --branch "$_ref" -q "$_url" "$CUST/$p" && echo "✓ plugin clonado: $p ($_ref)"
      fi
    done
    PYTHONIOENCODING=utf-8 python3 - "$ZSHRC" "${!REPOS[@]}" <<'PYEOF'
import re, sys
path, want = sys.argv[1], sys.argv[2:]
src = open(path, encoding="utf-8").read()
# auto-cura: a v0.1.2 deixou um ')' órfão após o comentário de exemplo do omz
# (quebrava bash E zsh). Só remove se a linha anterior for comentário.
src = re.sub(r'(^#[^\n]*zsh-syntax-highlighting[^\n]*\n)\)\n', r'\1', src, flags=re.MULTILINE)
# âncora no INÍCIO da linha: o template do omz tem um COMENTÁRIO de exemplo
# ("# Example format: plugins=(rails ...)") que não pode casar — só o bloco real
m = re.search(r'^plugins=\(([^)]*)\)', src, re.MULTILINE)
if not m:
    print("OK: nenhuma lista plugins=() encontrada - plugins ficam no modo standalone")
    sys.exit(0)
have = set(re.findall(r'[\w-]+', m.group(1)))
add = [w for w in want if w not in have]
if add:
    bloco = m.group(0)[:-1] + ' ' + ' '.join(add) + ')'
    src = src[:m.start()] + bloco + src[m.end():]
    open(path, "w", encoding="utf-8").write(src)
    print("OK: plugins acrescentados a plugins=():", ' '.join(add))
else:
    print("OK: todos os plugins ja estao na lista")
PYEOF
    grep -q '^plugins=.*zsh-autosuggestions' "$ZSHRC" && echo "✓ lista plugins=() verificada de verdade"
  # 6c) Sem Oh My Zsh: plugins em ~/.config/zest/plugins (módulo 10 carrega)
  else
    PDIR="$DEST/plugins"
    mkdir -p "$PDIR"
    for p in "${!REPOS[@]}"; do
      if [[ ! -d "$PDIR/$p" ]]; then
        read -r _url _ref <<< "${REPOS[$p]}"
        git clone --depth 1 --branch "$_ref" -q "$_url" "$PDIR/$p" && echo "✓ plugin standalone: $p ($_ref)"
      fi
    done
  fi
  # 6d) estilo das sugestões: o default do plugin é "fg=38;5;70" (cinza
  #     escuro), que some em terminais com fundo escuro. Força um cinza claro
  #     visível em qualquer tema. Só escreve se não estiver definido.
  if ! grep -q '^ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=' "$ZSHRC"; then
    echo 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"' >> "$ZSHRC"
    echo "✓ estilo de sugestão: fg=244 (cinza claro)"
  fi
fi

echo "═══════════════════════════════════════"
# 7) ferramentas — todas por padrão, via install-tool (zero root, sem sudo)
#    O CI passa --no-tools para o ciclo ficar rápido; o usuário comum recebe
#    tudo. O baixar falha em alguma? o próximo passo (shell) e o doctor
#    mostram o que faltou, e o usuário pode rodar "zest add <ferramenta>".
if (( WITH_TOOLS )); then
  echo ""
  echo "🔧 Instalando as 17 ferramentas (sem root, em ~/.local/bin)"
  echo "   Isso baixa ~60 MB e pode levar um minuto — o terminal fica livre."
  # nomes da primeira coluna de lib/tools.list (a segunda é o binário real, que
  # o install-tool já descobre sozinho)
  TOOLS_LIST=$(sed 's/[[:space:]]*$//' "$REPO_DIR/lib/tools.list" | grep -v '^#' | grep -v '^$' | awk '{print $1}')
  if bash "$REPO_DIR/lib/install-tool.sh" $TOOLS_LIST; then
    echo "✓ todas as ferramentas em $HOME/.local/bin"
  else
    echo "⚠️  Algumas ferramentas não instalaram — rode 'zest add <nome>' para ver"
    echo "   o erro de cada uma (e corrigir uma a uma)."
  fi
else
  echo "· ferramentas puladas (--no-tools)"
fi

# 8) shell padrão — se ainda for bash (ou outro), o Zest nunca carrega num
#    terminal novo. Em máquina nova esse é o caso comum, então o instalador
#    resolve sozinho. Trocar o shell da conta é mudança no sistema: o chsh pede
#    a senha do próprio usuário, por isso as tentativas vão da mais silenciosa
#    (já autorizada) até pedir a senha — e sempre sobra a instrução pronta.
CURSHELL=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
[[ -z "$CURSHELL" ]] && CURSHELL="${SHELL:-/bin/bash}"
ZSHBIN="$(command -v zsh)"
# "É o mesmo arquivo?" com o teste nativo -ef, que compara device+inode. Em
# distro com usrmerge /bin/zsh e /usr/bin/zsh são o mesmo arquivo, mas o passwd
# pode ter gravado qualquer um dos dois: comparando strings, o instalador dizia
# "seu shell não é zsh" numa conta que já usava zsh. -ef não depende de
# realpath/readlink, que faltam em container enxuto.
SHELL_OK=0
if [[ -n "$ZSHBIN" && -n "$CURSHELL" && "$CURSHELL" -ef "$ZSHBIN" ]]; then
  SHELL_OK=1
fi

if (( ! SHELL_OK )); then
  echo ""
  echo "🐚 Shell padrão: $CURSHELL — o Zest só carrega no zsh"
  TROCA="s"
  if _resposta=$(ask "   Trocar o shell padrão para zsh? [S/n] "); then
    TROCA="$_resposta"
  fi
  if [[ ! "$TROCA" =~ ^[nN] ]]; then
    USER_NAME=$(id -un)
    # a) alguns sistemas (e todo ambiente sem PAM de senha) aceitam direto
    if chsh -s "$ZSHBIN" 2>/dev/null; then
      SHELL_OK=1
    # b) com terminal de verdade o chsh pede a senha do próprio usuário
    elif has_tty && chsh -s "$ZSHBIN" 2>/dev/null < /dev/tty; then
      SHELL_OK=1
    # c) sudo sem senha (containers e CI costumam ter)
    elif command -v sudo >/dev/null 2>&1 \
      && sudo -n chsh -s "$ZSHBIN" "$USER_NAME" 2>/dev/null; then
      SHELL_OK=1
    # d) sudo pedindo a senha — a troca já foi aprovada na pergunta acima
    elif has_tty && command -v sudo >/dev/null 2>&1; then
      echo "   Último caminho: sudo (ele pede sua senha)"
      if sudo chsh -s "$ZSHBIN" "$USER_NAME" 2>/dev/null < /dev/tty; then
        SHELL_OK=1
      fi
    fi
    if (( SHELL_OK )); then
      echo "✓ Shell padrão alterado para zsh — feche e abra o terminal."
    else
      echo "⚠️  Não consegui trocar o shell automaticamente. Uma linha resolve:"
      echo "       sudo chsh -s $ZSHBIN $USER_NAME"
      echo "   (ou, sem trocar nada, entre no zsh com:  $ZSHBIN -l)"
    fi
  else
    echo "   Mantive $CURSHELL — para trocar depois:  chsh -s $ZSHBIN"
  fi
fi

# 9) PATH em ~/.local/bin — sem isso, um terminal novo não vê 'zest' nem as
#    ferramentas. O Zest não pode confiar em 'o terminal abre zsh': o chsh
#    pode falhar (sem sudo, sem PAM), o terminal pode abrir bash mesmo assim,
#    e um terminal que já estava aberto antes da troca continua bash.
#    Cobrimos os dois lados: .bashrc (bash) e .zprofile (zsh). O uninstall
#    remove os dois e devolve cada um como estava.
#
#    Bug que motivou isso: em container root, o chsh dava certo e o shell
#    virava zsh — mas o bloco do PATH só era escrito quando o shell AINDA
#    não era zsh, então um terminal bash aberto antes da troca via 'zest:
#    command not found' mesmo com o Zest instalar perfeitamente.
zest_path_block() {
  cat <<'ZESTEOF'

# >>> zest >>>
# Ferramentas do Zest (fzf, rg, fd, bat, eza, delta, zoxide, jq, yq, duf,
# lazygit, direnv, tldr, atuin, mise, uv, thefuck) ficam em ~/.local/bin.
export PATH="$HOME/.local/bin:$PATH"
# <<< zest <<<
ZESTEOF
}
zest_append() { # arquivo
  local f="$1"
  [[ -f "$f" ]] || : > "$f"
  if ! grep -q ">>> zest >>>" "$f" 2>/dev/null; then
    zest_path_block >> "$f"
    echo "✓ PATH do Zest adicionado a $f"
  else
    echo "· bloco do Zest já estava em $f"
  fi
}
zest_append "$HOME/.bashrc"
# .zprofile: o zsh lê .zprofile em login shells, e em container a imagem
# do Debian não tem .zprofile por padrão — então o PATH sumia do zsh.
zest_append "$HOME/.zprofile"

echo ""
echo "✅ Pronto! Ative com:  exec zsh   (ou feche e abra o terminal)"
echo "   Diagnóstico:        zest doctor"
echo "   Ferramentas:        fzf · rg · fd · bat · eza · delta · zoxide · jq · yq · duf · lazygit · direnv · tldr · atuin · mise · uv · thefuck"
if [[ -f "$DEST/prompt" ]]; then
  echo "   Prompt:             $(cat "$DEST/prompt") (troque com: zest prompt zest|compact|plain|off)"
else
  echo "   Prompt:             o que você já usa (Oh My Zsh/starship/p10k)"
fi
echo "   Desfazer tudo:      ./uninstall.sh"
