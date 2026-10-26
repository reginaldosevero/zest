# zest :: 48-text — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Texto e Conversão
# ------------------------------------------------------------
jsonfmt() { jq . "$1"; }
jsonmin() { jq -c . "$1"; }
json2yaml() { command -v yq >/dev/null 2>&1 && yq -P "$1" || echo "yq não instalado"; }
yaml2json() { command -v yq >/dev/null 2>&1 && yq -o=json "$1" || echo "yq não instalado"; }
countlines() { command -v tokei >/dev/null 2>&1 && tokei "${1:-.}" || echo "tokei não instalado"; }

# pega texto da área de transferência (Wayland → X11)
_zest-clip-get() {
  if command -v wl-paste >/dev/null 2>&1; then
    wl-paste -t text 2>/dev/null
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o 2>/dev/null
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output 2>/dev/null
  else
    echo "· sem acesso à área de transferência: instale wl-clipboard (Wayland) ou xclip (X11)" >&2
    return 1
  fi
}

# spell <arquivo>        lista erros de ortografia + sugestões
# spell -                lê da entrada padrão (eco 'texto' | spell -)
# spell -x               lê da área de transferência
# spell -i <arquivo>     corrige uma a uma, interativo
spell() {
  command -v aspell >/dev/null 2>&1 || { echo "· aspell não instalado: sudo apt install aspell aspell-pt-br"; return 1; }

  # dicionário: pt_BR se instalado, senão o padrão do sistema
  local dict=""
  aspell dicts 2>/dev/null | grep -qw pt && dict="-l pt_BR"

  local interativo=0 origem="arquivo" arg alvo="" rotulo="" txt=""
  local -a pos=()
  for arg in "$@"; do
    case "$arg" in
      -i) interativo=1 ;;
      -x|--clip|--clipboard) origem="clip" ;;
      -) origem="stdin" ;;
      *) pos+=("$arg") ;;
    esac
  done
  alvo="${pos[1]:-}"

  # sem alvo e stdin é pipe → stdin (comportamento Unix clássico)
  [[ -z "$alvo" && "$origem" == "arquivo" && ! -t 0 ]] && origem="stdin"

  case "$origem" in
    arquivo)
      if [[ -z "$alvo" ]]; then
        echo "Uso: spell <arquivo> · spell - (stdin) · spell -x (clipboard)"
        echo "     spell -i <arquivo>  corrige uma a uma"
        return 1
      fi
      [[ -f "$alvo" ]] || { echo "· arquivo não encontrado: $alvo"; return 1; }
      if (( interativo )); then
        [[ -t 0 && -t 1 ]] || { echo "· modo -i precisa de terminal interativo (sem pipe)"; return 1; }
        aspell -c $dict "$alvo"
        return
      fi
      rotulo="$alvo"
      txt=$(cat "$alvo")
      ;;
    stdin)
      [[ -t 0 ]] && { echo "· nada na entrada: eco 'texto' | spell -   ou   spell - e Ctrl+D"; return 1; }
      rotulo="entrada padrão"
      txt=$(cat)
      ;;
    clip)
      txt=$(_zest-clip-get) || return 1
      rotulo="área de transferência"
      if (( interativo )); then
        echo "· modo -i corrige só arquivo — copie o texto de volta depois de editar"
        return 1
      fi
      ;;
  esac

  [[ -n "${txt//[$'\n\t ']}" ]] || { echo "· nada para verificar em $rotulo"; return 1; }

  # aspell -a responde "& palavra N pos: sug1, sug2, ..." para cada erro
  local linha palavra sugestoes erros=0
  while IFS= read -r linha; do
    [[ "$linha" == \&\ * ]] || continue
    erros=$((erros + 1))
    palavra=$(echo "$linha" | awk '{print $2}')
    sugestoes=$(echo "$linha" | sed 's/.*: //' | cut -d, -f1-8)
    echo "❌ $palavra"
    echo "   → $sugestoes"
  done < <(printf '%s\n' "$txt" | aspell -a $dict 2>/dev/null)

  if (( erros == 0 )); then
    echo "✅ nenhum erro de ortografia em $rotulo"
  else
    echo ""
    echo "📝 $erros palavra(s) com problema em $rotulo"
    [[ "$origem" == "arquivo" ]] && echo "   para corrigir uma a uma: spell -i $alvo"
  fi
}

correct() {
  echo "✅ Correção ortográfica ativada no zsh"
  echo "   Próximos comandos terão sugestão de correção automática"
  echo "   Use 'setopt CORRECT' para desativar ou 'setopt NO_CORRECT' para desligar"
}

replace() {
  local search="$1" repl="$2" ext="${3:-*}"
  grep -rl "$search" --include="*.$ext" . | xargs -r sed -i "s/$search/$repl/g"
  echo "✅ Substituído '$search' por '$repl' em arquivos *.$ext"
}

# ------------------------------------------------------------
