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
if [[ ! -f "$REPO_DIR/lib/tools.list" ]]; then
  echo "❌ Não encontrei os arquivos do Zest ao lado deste script."
  echo "   O instalador precisa do repositório (lib/, modules/). Rode assim:"
  echo "     git clone https://github.com/reginaldosevero/zest.git"
  echo "     cd zest && ./install.sh"
  exit 1
fi
# detecção de distro (lib/distro.sh) — usada no passo 1 e no install-tool
source "$REPO_DIR/lib/distro.sh"
DEST="$HOME/.config/zest"
ZSHRC="$HOME/.zshrc"
WITH_PLUGINS=0
WITH_OMZ=0
WITH_TOOLS=1
for arg in "$@"; do
  case $arg in
    --with-plugins) WITH_PLUGINS=1 ;;
    --with-omz)     WITH_OMZ=1; WITH_PLUGINS=1 ;;   # instala o Oh My Zsh se faltar
    --no-tools)     WITH_TOOLS=0 ;;                   # CI: pula as 17 ferramentas
  esac
done

# Pergunta que funciona até em "curl ... | bash".
#   Nesse modo o stdin É o pipe com o próprio script: um `read` dali engoliria o
#   resto da instalação e nada seria perguntado. Então, quando o stdin não é um
#   terminal, a leitura vai para /dev/tty (o terminal de verdade). Sem terminal
#   nenhum (CI, cron), devolve 1 e quem chama usa o padrão — nunca lê do stdin.
ask() {
  local _resposta
  if [[ -t 0 ]]; then
    IFS= read -r -p "$1" _resposta || return 1
  elif [[ -c /dev/tty ]]; then
    IFS= read -r -p "$1" _resposta < /dev/tty || return 1
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

# 1) dependências — o Zest instala SOZINHO o que falta (sudo, ou su no Debian cru)
NEED=()
command -v zsh >/dev/null 2>&1 || NEED+=(zsh)
command -v git >/dev/null 2>&1 || NEED+=(git)
command -v curl >/dev/null 2>&1 || NEED+=(curl)
if [[ $WITH_PLUGINS == 1 && ! -d "$HOME/.oh-my-zsh" ]]; then
  command -v python3 >/dev/null 2>&1 || NEED+=(python3)
fi

if (( ${#NEED[@]} )); then
  PM=$(zest_pm_detect) || PM=""
  if [[ -z "$PM" ]]; then
    echo "❌ Faltam: ${NEED[*]} — e não encontrei apt/dnf/pacman/zypper/apk para instalá-los."
    echo "   Instale manualmente e rode este instalador de novo."
    exit 1
  fi

  echo "📦 Faltam dependências: ${NEED[*]}"
  echo "   Gerenciador detectado: $PM — pode pedir sua senha (sudo) ou a do root (su)…"
  zest_pm_update "$PM" || true
  if zest_pm_install "$PM" "${NEED[@]}"; then
    echo "✓ dependências instaladas (via $PM)"
  else
    echo "❌ Não consegui instalar automaticamente. Faça manualmente e rode de novo:"
    case "$PM" in
      apt-get) echo "   sudo apt-get install ${NEED[*]}" ;;
      dnf)     echo "   sudo dnf install ${NEED[*]}" ;;
      pacman)  echo "   sudo pacman -Sy --noconfirm ${NEED[*]}" ;;
      zypper)  echo "   sudo zypper install -y ${NEED[*]}" ;;
      apk)     echo "   sudo apk add ${NEED[*]}" ;;
    esac
    exit 1
  fi
fi
echo "✓ zsh encontrado: $(zsh --version)"

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

# 3) copia módulos e lib (idempotente)
mkdir -p "$DEST"
cp -r "$REPO_DIR/modules" "$REPO_DIR/lib" "$DEST/" 2>/dev/null || true
mkdir -p "$DEST/modules" "$DEST/lib"
cp "$REPO_DIR"/modules/*.zsh "$DEST/modules/"
[[ -d "$REPO_DIR/lib" ]] && cp -r "$REPO_DIR"/lib/* "$DEST/lib/" 2>/dev/null || true
chmod +x "$REPO_DIR/bin/zest"
mkdir -p "$HOME/.local/bin"
cp "$REPO_DIR/bin/zest" "$HOME/.local/bin/zest"   # cópia (não symlink): sobrevive se a pasta do clone for apagada
echo "✓ comando 'zest' em $HOME/.local/bin"
echo "✓ módulos em $DEST"

# 4) backup do .zshrc (uma vez por dia, sem acumular)
if [[ -f "$ZSHRC" ]]; then
  BAK="$ZSHRC.zest-bak-$(date +%Y%m%d)"
  # -p preserva permissões: um .zshrc 600 (com tokens) não vira backup 644
  [[ -f "$BAK" ]] || cp -p "$ZSHRC" "$BAK"
  echo "✓ backup: $BAK"
fi

# 5) bloco marcado no .zshrc (nunca duplica)
if grep -q ">>> zest >>>" "$ZSHRC" 2>/dev/null; then
  echo "✓ .zshrc já carrega o Zest (nada duplicado)"
else
  cat >> "$ZSHRC" <<'EOF'

# >>> zest >>>
# Zest 🌶️ — o tempero do seu terminal (https://github.com/reginaldosevero/zest)
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
SHELL_OK=0
[[ "$CURSHELL" == "$ZSHBIN" ]] && SHELL_OK=1

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
    elif [[ -c /dev/tty ]] && chsh -s "$ZSHBIN" < /dev/tty 2>/dev/null; then
      SHELL_OK=1
    # c) sudo sem senha (containers e CI costumam ter)
    elif command -v sudo >/dev/null 2>&1 \
      && sudo -n chsh -s "$ZSHBIN" "$USER_NAME" 2>/dev/null; then
      SHELL_OK=1
    # d) sudo pedindo a senha — a troca já foi aprovada na pergunta acima
    elif [[ -c /dev/tty ]] && command -v sudo >/dev/null 2>&1; then
      echo "   Último caminho: sudo (ele pede sua senha)"
      if sudo chsh -s "$ZSHBIN" "$USER_NAME" < /dev/tty; then
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

# 9) PATH em shell não-zsh — se a conta ainda abre bash, o terminal novo não vê
#    as ferramentas em ~/.local/bin nem o ~/.zprofile. O bloco no ~/.bashrc é a
#    rede de segurança: os comandos funcionam mesmo enquanto a conta não vira
#    zsh. O uninstall remove o bloco e devolve o arquivo como estava.
#    (Aqui só PATH: os módulos do Zest são código zsh e não podem ser carregados
#     dentro do bash.)
BASHRC="$HOME/.bashrc"
if (( ! SHELL_OK )); then
  [[ -f "$BASHRC" ]] || : > "$BASHRC"
  if ! grep -q ">>> zest >>>" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" <<'ZESTEOF'

# >>> zest >>>
# Ferramentas do Zest (fzf, rg, fd, bat, eza, delta, zoxide, jq, yq, duf,
# lazygit, direnv, tldr, atuin, mise, uv, thefuck) ficam em ~/.local/bin.
export PATH="$HOME/.local/bin:$PATH"
# <<< zest <<<
ZESTEOF
    echo "✓ PATH do Zest adicionado ao ~/.bashrc"
  else
    echo "· bloco do Zest já estava no ~/.bashrc"
  fi
fi

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
