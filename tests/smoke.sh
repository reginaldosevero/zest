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
            weather lua news crypto stocks calc timer stopwatch \
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
# o corpo do ask() tem de ter um caminho pelo /dev/tty (senão vira leitura de stdin)
if [[ -z "$READ_CRU" ]] \
   && awk '/^ask\(\) \{/ { in_ask = 1 }
           in_ask && /^\}/ { in_ask = 0 }
           in_ask && /read .*\/dev\/tty/ { found = 1 }
           END { exit !found }' install.sh; then
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
# 14) o extrator REAL (lib/install-helpers.sh) acha o ELF em qualquer layout
#     (v0.3.1: atuin passou a vir dentro de "atuin-<triple>/" e um "tar … atuin"
#      fixo quebrou o install em campo, com checksum OK — a impressão era de
#      download corrompido, era layout do asset. Teste offline, sem rede:
#      usa as MESMAS funções do instalador (uma cópia aqui divergiria dele) e
#      confirma que resolve raiz, subpasta e recusa arquivos sem ELF.)
EX_HOME="$(mktemp -d)"
mkdir -p "$EX_HOME/bin" "$EX_HOME/pkg/raiz" "$EX_HOME/pkg/sub/atuin-x86_64-unknown-linux-musl" "$EX_HOME/pkg/so"
printf '\x7fELF' > "$EX_HOME/pkg/raiz/fzf"                            # layout antigo: na raiz
printf '\x7fELF' > "$EX_HOME/pkg/sub/atuin-x86_64-unknown-linux-musl/atuin"  # layout novo: em subpasta
printf 'nao e elf' > "$EX_HOME/pkg/so/README.md"                       # sem ELF nenhum
tar czf "$EX_HOME/raiz.tgz"  -C "$EX_HOME/pkg" raiz
tar czf "$EX_HOME/sub.tgz"   -C "$EX_HOME/pkg" sub
tar czf "$EX_HOME/so.tgz"    -C "$EX_HOME/pkg" so
EX_OUT=$(bash -c '
  T="'"$EX_HOME"'"; BIN="'"$EX_HOME"'/bin"
  source lib/install-helpers.sh
  ok=0
  # 1) binário na raiz do tarball
  p=$(unpack_bin "$T/raiz.tgz" fzf)        || { echo "FALHOU_RAIZ"; ok=1; }
  check_elf "$p"                            || { echo "FALHOU_RAIZ_ELF"; ok=1; }
  # 2) binário dentro de subpasta (o caso do atuin)
  p=$(unpack_bin "$T/sub.tgz" atuin)        || { echo "FALHOU_SUB"; ok=1; }
  finish_bin "$p" atuin                     || { echo "FALHOU_SUB_MOV"; ok=1; }
  [[ -x "$BIN/atuin" ]]                     || { echo "FALHOU_SUB_DESTINO"; ok=1; }
  # 3) tarball sem ELF: precisa FALHAR com mensagem, nunca instalar lixo
  p=$(unpack_bin "$T/so.tgz" atuin 2>/dev/null) && { echo "ACEITOU_LIXO"; ok=1; }
  finish_bin "$p" atuin 2>/dev/null         && { echo "MOVEU_LIXO"; ok=1; }
  (( ok == 0 )) && echo "EX_OK"
' 2>&1)
if echo "$EX_OUT" | grep -q EX_OK; then
  echo "  ✓ unpack_bin resolve raiz, subpasta e recusa arquivo sem ELF"
else
  echo "  ✗ unpack_bin: $(echo "$EX_OUT" | tr '\n' ' ')"; FAIL=1
fi
rm -rf "$EX_HOME"

# 15) o shell padrão é comparado como ARQUIVO, não como texto
#     usrmerge: /bin/zsh e /usr/bin/zsh são o mesmo arquivo, e o passwd pode
#     guardar qualquer um. Comparação de string dizia "não é zsh" para quem já
#     usava zsh (e o instalador tentava chsh à toa).
if grep -qE '"\$CURSHELL" -ef "\$ZSHBIN"' install.sh \
   && ! grep -qE '"\$CURSHELL" == "\$ZSHBIN"' install.sh; then
  echo "  ✓ shell padrão comparado por inode (-ef), não por string"
else
  echo "  ✗ install.sh compara o shell padrão como texto (quebra com usrmerge)"; FAIL=1
fi

# 16) nada pergunta abrindo /dev/tty às cegas
#     '[[ -c /dev/tty ]]' mente em container sem terminal de controle: o device
#     existe, o open falha e o "No such device or address" aparece no meio da
#     instalação. Só o has_tty(), que testa abrindo de verdade com o erro calado.
TTYLEAK=$(grep -nE '\[\[ -c /dev/tty \]\]|< /dev/tty' install.sh \
  | grep -v 'exec 3<' | grep -v '2>/dev/null')
if [[ -z "$TTYLEAK" ]] && grep -q 'has_tty()' install.sh; then
  echo "  ✓ /dev/tty só é usado com o erro calado (nada de erro na tela)"
else
  echo "  ✗ install.sh abre /dev/tty sem calar o erro:$(echo "${TTYLEAK:-}" | tr '\n' ' ')"; FAIL=1
fi

# 17) o PATH do Zest vai para .bashrc E .zprofile SEM depender do shell atual
#     (bug real: o bloco só era escrito quando o login shell NÃO era zsh — e
#      como o chsh rodava antes, num container root o bloco era pulado e o
#      usuário via 'zest: command not found' em qualquer terminal bash. O
#      teste roda o instalador de verdade num HOME falso e confere os dois.)
P_HOME="$(mktemp -d)"
P_SHIM="$(mktemp -d)"
# chsh/sudo falham de propósito: o teste não pode mexer no shell real de quem
# roda o smoke, e o ponto aqui é justamente o PATH funcionar MESMO quando o
# chsh não dá certo.
printf '#!/bin/sh\nexit 1\n' > "$P_SHIM/chsh"
printf '#!/bin/sh\nexit 1\n' > "$P_SHIM/sudo"
chmod +x "$P_SHIM/chsh" "$P_SHIM/sudo"
if env -i HOME="$P_HOME" PATH="$P_SHIM:$PATH" TERM=dumb bash install.sh --no-tools </dev/null >/dev/null 2>&1 \
   && grep -q ">>> zest >>>" "$P_HOME/.bashrc" \
   && grep -q ">>> zest >>>" "$P_HOME/.zprofile" \
   && [[ -x "$P_HOME/.local/bin/zest" ]]; then
  echo "  ✓ PATH do Zest chega ao bash E ao zsh (não depende do chsh dar certo)"
else
  echo "  ✗ install.sh não garante o PATH em ~/.bashrc e ~/.zprofile"; FAIL=1
fi
rm -rf "$P_HOME" "$P_SHIM"

# 18) lib/sweep.sh comenta 'source X' onde X não existe — sem tocar no conteúdo
#     real do usuário (nunca apaga, só comenta). Testa os três formatos:
#     absoluto (/caminho), tilde (~/caminho) e variável conhecida ($ZSH, $HOME).
#     Regra que o teste garante: só se comenta com CERTEZA. Uma variável que o
#     sweep não conhece ($MINHA_VAR) é deixada intacta, porque um falso positivo
#     quebra o shell do usuário. E 'source $ZSH/oh-my-zsh.sh' NUNCA é comentado:
#     comentar essa linha derruba o Oh My Zsh e todos os plugins — foi o bug que
#     fez a autossugestão sumir. Roda com 'set -u' para pegar o '$ZSH: unbound'.
S_HOME="$(mktemp -d)"
printf 'export ZSH="$HOME/.oh-my-zsh"\nsource $ZSH/oh-my-zsh.sh\n\nalias ll="ls -la"\nsource ~/naoexiste/roda.sh\nsource /caminho/que/nao/existe.sh\nsource $MINHA_VAR/bin/roda.sh\n' > "$S_HOME/.zshrc"
if env -i HOME="$S_HOME" PATH="$PATH" bash -c "
  set -euo pipefail
  source '$(dirname "$0")/../lib/sweep.sh'
  zest_sweep_orphans '$S_HOME/.zshrc'
" && grep -q '^[[:space:]]*source \$ZSH/oh-my-zsh.sh' "$S_HOME/.zshrc" \
   && grep -qE '# \[zest\] source órfão.*: (~/naoexiste/roda.sh|'"$S_HOME"'/naoexiste/roda.sh)' "$S_HOME/.zshrc" \
   && grep -q '# \[zest\] source órfão.*: /caminho/que/nao/existe.sh' "$S_HOME/.zshrc" \
   && grep -q '^[[:space:]]*source \$MINHA_VAR/bin/roda.sh' "$S_HOME/.zshrc" \
   && grep -q 'alias ll="ls -la"' "$S_HOME/.zshrc"; then
  echo "  ✓ sweep.sh comenta órfãos certos, poupa frameworks e não toca em \$VAR desconhecida"
else
  echo "  ✗ sweep.sh não comentou os formatos corretamente ou protegeu frameworks"; FAIL=1
fi
rm -rf "$S_HOME"

# 19) autossugestão VISÍVEL: um zsh interativo num pseudo-terminal de verdade
#     mostra o complemento vindo do histórico? 'type _zsh_autosuggest_start' não
#     basta — o usuário não vê função, vê cinza atrás do cursor. Roda numa HOME
#     de mentira, com um .zshrc mínimo que só carrega o plugin: sem Oh My Zsh e
#     sem rede. Pula (não falha) onde faltar python3, zsh ou o plugin.
AS_SRC=""
for c in "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
         /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f "$c" ]] && AS_SRC="$c" && break
done
AS_HOME="$(mktemp -d)"
if command -v python3 >/dev/null 2>&1 && command -v zsh >/dev/null 2>&1 && [[ -n "$AS_SRC" ]]; then
  { printf 'export HISTFILE="%s/.zsh_history"\n' "$AS_HOME"
    printf 'HISTSIZE=1000 SAVEHIST=1000\n'
    printf 'source "%s"\n' "$AS_SRC"
  } > "$AS_HOME/.zshrc"
  if env -i HOME="$AS_HOME" PATH="$PATH" TERM=xterm-256color LANG=C.UTF-8 \
       python3 "$(dirname "$0")/autosuggest.py" >/dev/null 2>&1; then
    echo "  ✓ autossugestão aparece na tela (PTY real)"
  else
    echo "  ✗ autossugestão não apareceu na tela — o plugin carrega mas não sugere"; FAIL=1
  fi
else
  echo "· autossugestão: pulado (falta python3, zsh ou o plugin)"
fi
rm -rf "$AS_HOME"

# 20) nenhum 'grep -q' pendurado em pipe no lib/distro.sh: o -q fecha o pipe no
#     primeiro match, o comando da esquerda leva SIGPIPE e, sob 'set -o
#     pipefail', a função devolve 141 MESMO quando o pacote existe — o instalador
#     achava que procps/iproute2 não existiam e seguia sem eles.
if grep -nE '\|[[:space:]]*(LC_ALL=[^ ]+[[:space:]]+)?grep[[:space:]]+[^|]*-q([[:space:]]|$)' lib/distro.sh >/dev/null; then
  echo "  ✗ lib/distro.sh tem 'grep -q' em pipe (SIGPIPE + pipefail = falso ausente)"; FAIL=1
else
  echo "  ✓ distro.sh sem 'grep -q' em pipe (SIGPIPE não vira pacote ausente)"
fi

# 21) o instalador cobre os utilitários de sistema que os wrappers chamam: sem
#     `ps` o topcpu morre e o usuário culpa o Zest. Varredura feita com PATH
#     inexistente (nada achado) + tabela de pacotes por distro.
if env -i HOME="$(mktemp -d)" PATH="/nonexistent" "$(command -v bash)" -c "
  source '$(dirname "$0")/../lib/distro.sh'
  m=\$(zest_base_missing)
  [[ \$m == *ps* && \$m == *ss* ]] || exit 1
  [[ \$(zest_base_pkg ps apt-get) == procps ]] || exit 1
  [[ \$(zest_base_pkg ss apt-get) == iproute2 ]] || exit 1
  zest_base_pkg binario-inexistente apt-get && exit 1
  exit 0
"; then
  echo "  ✓ wrappers têm dependência de sistema mapeada (ps→procps, ss→iproute2)"
else
  echo "  ✗ varredura de utilitários de sistema está errada"; FAIL=1
fi

# 22) nenhum filtro de jq com colchete fora de aspas nos módulos: no zsh o
#     '.result[0]' solto é GLOB e a função morre com "no matches found" antes de
#     chamar o jq — foi exatamente o que derrubou o 'stocks'.
if grep -rnE '\bjq[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*[^"'"'"']*[][]' modules/ bin/zest >/dev/null; then
  echo "  ✗ jq com colchete fora de aspas (o zsh trata como glob):"
  grep -rnE '\bjq[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*[^"'"'"']*[][]' modules/ bin/zest | sed 's/^/      /'
  FAIL=1
else
  echo "  ✓ filtros de jq entre aspas (glob do zsh não engole o '[0]')"
fi

# 23) 'local x' duas vezes na mesma função faz o zsh ECOAR a atribuição ('x=''')
#     na saída. Foi o que apareceu na frente do preço: 'local json saida erro' e
#     mais abaixo 'local erro'. Varre módulos e bin/zest procurando a repetição.
#     Tokeniza com split, não com match(): o mawk do Debian pula tokens no laço
#     com match e a guarda viraria um enfeite que nunca dispararia. Só olha linha
#     que COMEÇA com local (comentário e prosa ficam de fora) e corta em ';' e
#     em '#', senão 'local total; total=$(...)' vira falsa acusação.
if DUP=$(env LC_ALL=C awk '
  /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*\(\)[[:space:]]*\{/ { fn = $1; delete seen; next }
  /^[[:space:]]*\}/ { fn = ""; next }
  !fn { next }
  /^[[:space:]]*local[[:space:]]/ {
    line = $0
    sub(/#.*/, "", line)
    n = split(line, seg, /;/)
    for (s = 1; s <= n; s++) {
      part = seg[s]
      gsub(/^[[:space:]]+/, "", part)
      if (part !~ /^local([[:space:]]|$)/) continue
      sub(/^local[[:space:]]*/, "", part)
      m = split(part, tok, /[[:space:]]+/)
      for (t = 1; t <= m; t++) {
        if (tok[t] ~ /^-/) continue              # local -a / -r: opção, não nome
        if (tok[t] !~ /^[A-Za-z_][A-Za-z0-9_]*/) continue
        name = tok[t]
        sub(/=.*/, "", name)                     # local x=y declara x
        if (name in seen)
          printf "%s:%d: local %s repetido (primeira vez na linha %d)\n", FILENAME, FNR, name, seen[name]
        seen[name] = FNR
      }
    }
  }
' modules/*.zsh bin/zest) && [[ -z "$DUP" ]]; then
  echo "  ✓ nenhum 'local' redeclarado (zsh ecoaria 'variável=')"
else
  echo "  ✗ 'local' redeclarado — o zsh imprime 'variável=' na saída do comando:"
  printf '%s\n' "$DUP" | sed 's/^/      /'
  FAIL=1
fi

# 24) apóstrofo dentro do programa jq escrito entre aspas simples: o comentário
#     mora DENTRO do filtro multi-linha e um ' nele fecha a aspa do shell — o
#     resto da linha vira código solto e o zsh morre em "no matches found" no
#     primeiro colchete. Foi assim que o 'stocks' formatado quebrou: um comentário
#     dentro do filtro dizia 'tostring | [-3:]' não compila.
#     Dentro do bloco aberto pelo jq, nenhum apóstrofo é permitido.
if AP=$(env LC_ALL=C awk -v q="'" '
  FILENAME != file { file = FILENAME; injq = 0 }
  !injq {
    if ($0 ~ /(^|[^A-Za-z_])jq[[:space:]]/ && gsub(q, q) % 2 == 1) injq = 1
    next
  }
  {
    n = gsub(q, q)
    if (n % 2 == 1) { injq = 0; next }          # fechou o programa: linha normal
    if (n > 0) printf "%s:%d: apóstrofo dentro do programa jq — fecha a aspa simples\n", FILENAME, FNR
  }
' modules/*.zsh bin/zest) && [[ -z "$AP" ]]; then
  echo "  ✓ nenhum apóstrofo dentro de filtro jq (a aspa simples não se abre sozinha)"
else
  echo "  ✗ apóstrofo dentro de programa jq entre aspas simples:"
  printf '%s\n' "$AP" | sed 's/^/      /'
  FAIL=1
fi

echo "════════════════════"
(( FAIL == 0 )) && echo "✅ smoke test passou" || { echo "❌ smoke test falhou"; exit 1; }
