#!/usr/bin/env bash
# zest :: smoke test — roda em qualquer distro com zsh (não precisa das ferramentas)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
FAIL=0

echo "🌶️  smoke test"

# 1) sintaxe de todos os módulos
for f in modules/*.zsh; do
  if zsh -n "$f" 2>/dev/null; then
    echo "  ✓ sintaxe: $f"
  else
    echo "  ✗ sintaxe: $f"; FAIL=1
  fi
done

# 2) todos os módulos carregam e as funções essenciais existem
#    (sem Oh My Zsh, sem ferramentas externas — as guardas é que fazem o trabalho)
export ZEST_QUIET=1
if zsh -c '
  for f in modules/*.zsh(N); do source "$f"; done
  missing=""
  for fn in sysinfo topmem topcpu spell correct note notes noterm noteclean todo todos tododone \
            weather moon news crypto stocks calc timer stopwatch \
            gci gpr gsync gstash gfiles gclean_branches \
            dsh dlogsall drmi dbuildpush dcp \
            nodeproject pyproject goproject rustproject \
            diskusage_dir ipinfo sysclean updateall \
            jsonfmt jsonmin json2yaml yaml2json countlines replace \
            portcheck download speedtest sslinfo backup_dir syncdir \
            ts2date date2ts worldtime procs git ajuda \
            histnum histsed histdel histclear histsearch histcount histclean \
            _zest-pm-detect _zest-pm-hint _zest-pm-upgrade; do
    (( $+functions[$fn] )) || missing="$missing $fn"
  done
  if [[ -n "$missing" ]]; then echo "FALTANDO:$missing"; exit 1; fi
  echo "FUNCOES_OK"
' 2>/dev/null | grep -q FUNCOES_OK; then
  echo "  ✓ funções essenciais (50+, sem Oh My Zsh e sem ferramentas externas)"
else
  echo "  ✗ carregamento de funções"; FAIL=1
fi

# 3) o CLI responde
./bin/zest version | grep -q "zest " && echo "  ✓ CLI: zest version" || { echo "  ✗ CLI"; FAIL=1; }

# 4) nenhum hardcode de distro fora do módulo de detecção (v0.2)
#    'sudo apt ...', 'dnf ...', 'pacman -S ...', 'zypper ...' dentro de um módulo
#    quebra em qualquer outra distro — quem conhece a distro é 06-pm.zsh.
HARDCODE=""
for f in modules/*.zsh; do
  case "$f" in *06-pm.zsh) continue ;; esac
  hit=$(sed 's/#.*//' "$f" 2>/dev/null | grep -nE 'sudo[[:space:]]+(apt|apt-get|dnf|pacman|zypper|apk)\b|(apt-get|zypper)[[:space:]]+install')
  [[ -n "$hit" ]] && HARDCODE="$HARDCODE
  $f: $hit"
done
if [[ -z "$HARDCODE" ]]; then
  echo "  ✓ sem hardcode de distro nos módulos"
else
  echo "  ✗ módulos chamando gerenciador direto:$HARDCODE"
  echo "    use as funções de modules/06-pm.zsh (_zest-pm-detect, _zest-pm-hint, …)"
  FAIL=1
fi

# 5) a cadeia de instalação funciona de ponta a ponta: install-tool carrega
#    lib/distro.sh e as funções de detecção respondem. Um lib/distro.sh quebrado
#    ou incompleto precisa derrubar o smoke, não só imprimir um aviso no meio.
CHAIN=$(bash -c '
  bash lib/install-tool.sh >/dev/null 2>/dev/null || echo "FALHA_USAGE "
  bash -c "source lib/distro.sh" 2>/dev/null || echo "FALHA_SOURCE "
  bash -c "source lib/distro.sh
          zest_pkg jq apt-get >/dev/null 2>&1 || echo FALHA_PKG " 2>/dev/null
  bash lib/install-tool.sh --prefer-pm 2>/dev/null | grep -q "prefer-pm" \
    || echo "FALHA_FLAG "' 2>/dev/null)
if [[ -z "$CHAIN" ]]; then
  echo "  ✓ cadeia install-tool + lib/distro.sh ok"
else
  echo "  ✗ cadeia de instalação: $CHAIN"; FAIL=1
fi

# 6) nenhuma função definida duas vezes
#    em shell, a segunda definição silencia a primeira — foi assim que um
#    zest_pkg antigo sobreviveu e passou por cima do correto em lib/distro.sh.
DUPS=$(cat lib/*.sh modules/*.zsh 2>/dev/null \
  | grep -oE '^[[:space:]]*(function[[:space:]]+)?(zest_[a-z_]+|_zest-[a-z-]+)[[:space:]]*\(\)' \
  | sed 's/[[:space:]]//g; s/()//; s/^function//' | sort | uniq -d)
if [[ -z "$DUPS" ]]; then
  echo "  ✓ nenhuma função interna duplicada"
else
  echo "  ✗ funções definidas mais de uma vez (a última vence): $(echo "$DUPS" | tr '\n' ' ')"; FAIL=1
fi

# 7) o mapa de pacotes nunca devolve nome cujo binário seria outro
#    (regra do CHANGELOG 0.2.0: só pacote que instala o binário com o nome esperado)
BADPKG=$(bash -c '
  source lib/distro.sh
  for pm in apt-get dnf pacman zypper apk; do
    for t in yq bat fd; do
      out=$(zest_pkg "$t" "$pm") && echo "  $t/$pm -> $out"
    done
  done' 2>/dev/null | grep -E "bat/apt-get|fd/apt-get|yq/")
if [[ -z "$BADPKG" ]]; then
  echo "  ✓ mapa de pacotes evita nomes de binário divergentes"
else
  echo "  ✗ pacote que instala binário com outro nome:$BADPKG"; FAIL=1
fi

# 8) o doctor testa o BINÁRIO real, não o nome do comando do zest add
#    (ripgrep → rg, tldr → tealdeer). Sem isso o doctor dizia "zest add
#    ripgrep" mesmo com o rg em ~/.local/bin.
#    Teste de ponta a ponta: HOME vazio (sem .local/bin no PATH) — todos
#    devem dizer "não instalado", e o doctor não deve dizer "zest add rg"
#    (que não é um comando do Zest, é o binário real).
SMOKE_HOME="$(mktemp -d)"
DOCTOR_OUT=$(env -u ZEST_HOME HOME="$SMOKE_HOME" bash bin/zest doctor 2>&1)
if echo "$DOCTOR_OUT" | grep -q "zest add rg"; then
  echo "  ✗ doctor sugere 'zest add rg' (binário real, não é comando do Zest)"; FAIL=1
elif echo "$DOCTOR_OUT" | grep -qE "→ não instalado"; then
  echo "  ✓ doctor testa o binário real (segunda coluna de tools.list)"
else
  echo "  ✗ doctor não listou nenhuma ferramenta"; FAIL=1
fi
rm -rf "$SMOKE_HOME"

# 9) a pergunta do instalador nunca lê do stdin
#    Em "curl … | bash" o stdin É o script: um `read` cru engole o resto da
#    instalação e nada é perguntado (foi o que calou a escolha do prompt).
READ_CRU=$(awk '
  /^ask\(\) \{/ { in_ask = 1 }
  in_ask && /^\}/ { in_ask = 0; next }
  in_ask { next }
  /^[[:space:]]*(IFS=[^[:space:]]+[[:space:]]+)?read( -[a-zA-Z]+)+/ && $0 !~ /\/dev\/tty/ && $0 !~ /<</ \
    { print NR ": " $0 }
' install.sh)
if [[ -z "$READ_CRU" ]] && grep -q 'read -r -p "$1" _resposta < /dev/tty' install.sh; then
  echo "  ✓ pergunta via /dev/tty (funciona em curl|bash)"
else
  echo "  ✗ install.sh lê do stdin (quebra curl|bash) — use ask():$READ_CRU"; FAIL=1
fi

# 10) o doctor cobra o shell padrão
#     Em máquina nova o login costuma ser bash: sem essa checagem o diagnóstico
#     dizia "tudo saudável" com o Zest morto em todo terminal novo.
env -u ZEST_HOME ZEST_REPO="$PWD" bash bin/zest doctor 2>&1 \
  | grep -q "· shell padrão" \
  && echo "  ✓ doctor checa o shell padrão" \
  || { echo "  ✗ doctor não checa o shell padrão"; FAIL=1; }

# 11) zest prompt aceita os 4 estilos e recusa os outros
PROMPT_HOME="$(mktemp -d)"
for estilo in zest compact plain off; do
  env -u ZEST_HOME HOME="$PROMPT_HOME" bash bin/zest prompt "$estilo" >/dev/null 2>&1 \
    || { echo "  ✗ zest prompt $estilo falhou"; FAIL=1; }
  [[ "$(cat "$PROMPT_HOME/.config/zest/prompt" 2>/dev/null)" == "$estilo" ]] \
    || { echo "  ✗ zest prompt $estilo não gravou o estilo"; FAIL=1; }
done
env -u ZEST_HOME HOME="$PROMPT_HOME" bash bin/zest prompt neon >/dev/null 2>&1 \
  && { echo "  ✗ zest prompt aceitou estilo inexistente"; FAIL=1; } \
  || echo "  ✓ zest prompt valida os estilos"
rm -rf "$PROMPT_HOME"

# 12) a segunda coluna de tools.list é só o nome do binário
#     Comento na mesma linha virava parte do nome testado ("rg # comentário"),
#     e aí todo 'zest add' falha com "desconhecida: <nome>".
BADTBL=$(awk '!/^[[:space:]]*#/ && NF > 0 && $2 != "" && $2 !~ /^[A-Za-z0-9._@-]+$/ { print FILENAME NR ": " $0 }' lib/tools.list)
if [[ -z "$BADTBL" ]]; then
  echo "  ✓ tools.list: segunda coluna é nome de binário limpo"
else
  echo "  ✗ tools.list com coluna 2 suja:$BADTBL"; FAIL=1
fi

# 13) o instalador instala a lista inteira, não nomes escritos à mão
#     (nomes soltos no install.sh ficam para trás quando a lista cresce — foi
#      assim que uv e thefuck ficaram de fora na instalação completa)
if grep -q 'REPO_DIR/lib/tools.list' install.sh \
  && ! grep -qE 'install-tool\.sh[[:space:]]+fzf' install.sh; then
  echo "  ✓ install.sh instala a lista de tools.list"
else
  echo "  ✗ install.sh tem lista de ferramentas à mão (use tools.list)"; FAIL=1
fi

echo "════════════════════"
(( FAIL == 0 )) && echo "✅ smoke test passou" || { echo "❌ smoke test falhou"; exit 1; }
