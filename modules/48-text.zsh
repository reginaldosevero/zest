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
  # a dica de instalação segue o gerenciador da máquina (nada de 'sudo apt' fixo)
  (( $+commands[aspell] )) || {
    echo "· aspell não instalado: $(_zest-pm-hint "$(_zest-pm-detect)" aspell aspell-pt-br)"
    return 1
  }

  # dicionário: pt_BR se instalado, senão padrão do sistema (array = 2 palavras)
  local -a dict
  aspell dicts 2>/dev/null | grep -qE '^(pt|pt_BR)$' && dict=(-l pt_BR)

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

# escolhe a sugestão que bate melhor com a palavra; compara sem acentos
# (awk em UTF-8 conta caracteres, não bytes); empate → 1ª da lista do aspell
_zest-spell-pick() {
  local w="$1"; shift
  printf '%s\n' "$@" | awk -v w="$w" '
    BEGIN {
      split("a a a a a a e e e e i i i i o o o o o u u u u c n", base, " ")
      n2 = split("àáâãäåèéêëìíîïòóôõöùúûüçñ", ac, "")
      for (j = 1; j <= n2; j++) norm[ac[j]] = base[j]
      bestn = -1
    }
    {
      s = $0
      n = 0
      while (n < length(w) && n < length(s)) {
        cw = tolower(substr(w, n+1, 1)); cs = tolower(substr(s, n+1, 1))
        if (cw in norm) cw = norm[cw]
        if (cs in norm) cs = norm[cs]
        if (cw != cs) break
        n++
      }
      if (n > bestn) { bestn = n; out = s }
    }
    END { print out }'
}

# widget ZLE: corrige a ortografia da palavra sob/atras do cursor (Alt+S)
_zest-spell-word() {
  command -v aspell >/dev/null 2>&1 || { zle -M "aspell não instalado"; return 1 }
  local WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'   # acentos ficam "dentro" da palavra

  # espaços à direita do cursor pertencem à palavra anterior
  local ltrim="${LBUFFER%"${LBUFFER##*[![:space:]]}"}"   # LBUFFER sem espaços finais
  local trail="${LBUFFER:${#ltrim}}"                      # os espaços que saíram
  local left_word="${ltrim##*[[:space:]]}"                # palavra até o cursor
  local right_word="${RBUFFER%%[[:space:]]*}"             # resto da palavra após o cursor
  local w="$left_word$right_word"
  [[ -n "$w" ]] || { zle -M "nada para verificar aqui"; return 1 }

  local -a dict
  aspell dicts 2>/dev/null | grep -qE '^(pt|pt_BR)$' && dict=(-l pt_BR)
  local resp
  resp=$(printf '%s\n' "$w" | aspell -a $dict 2>/dev/null | grep -m1 '^&')
  if [[ -z "$resp" ]]; then
    zle -M "✔ '$w' parece correta"
    return 0
  fi

  local -a sugestoes
  sugestoes=(${(f)"$(printf '%s' "${resp#*: }" | tr ',' '\n' | sed 's/^ *//')"})
  local sug
  sug=$(_zest-spell-pick "$w" "${sugestoes[@]}")
  [[ -n "$sug" ]] || { zle -M "sem sugestão para '$w'"; return 1 }

  local n_cut=$(( ${#ltrim} - ${#left_word} ))
  LBUFFER="${ltrim:0:$n_cut}$sug$trail"
  RBUFFER="${RBUFFER:${#right_word}}"
  zle -M "✔ corrigido: $w → $sug"
}
zle -N _zest-spell-word 2>/dev/null
bindkey -M emacs '\es' _zest-spell-word 2>/dev/null

correct() {
  setopt CORRECT
  echo "✅ correct: o zsh vai sugerir correção para comandos errados"
  echo "   Ex.: 'git stautos' → 'zsh: correct to git status? [n]'"
  echo "   Desligar: setopt NO_CORRECT"
  echo "   Dica: Alt+S corrige a ortografia da palavra sob o cursor (pt_BR)"
}

# replace <busca> <troca> [ext] — troca texto LITERAL (não regex) em todos os
# arquivos da extensão. Busca e troca vão escapadas para o sed: '.', '*', '/'
# etc. perdem o significado especial.
replace() {
  local search="$1" repl="$2" ext="${3:-*}"
  [[ -n "$search" ]] || { echo "Uso: replace <busca> <troca> [extensão]"; return 1; }
  # escapa metacaracteres na busca (\ & | / . * [ ] ^ $ ? + ( ) { })
  local esc_busca
  esc_busca=$(printf '%s' "$search" | sed 's/[.[\*^$?()+{}|\/\\]/\\&/g')
  # na substituição só \ & e / precisam de escape
  local esc_troca
  esc_troca=$(printf '%s' "$repl" | sed 's/[\/&\\]/\\&/g')
  grep -rlF -- "$search" --include="*.$ext" . \
    | xargs -r sed -i "s/${esc_busca}/${esc_troca}/g"
  echo "✅ Substituído '$search' por '$repl' em arquivos *.$ext"
}

# ------------------------------------------------------------
