# zest :: 41-daily — módulo do Zest (extraído e testado na prática)
#  ALIASES / FUNÇÕES — Produtividade do dia a dia
# ------------------------------------------------------------
# ===== NOTAS =====
# note           → modo interativo: digite a nota + Enter (várias linhas ok, linha vazia termina)
# note texto...  → salva direto, sem prompt
# notes          → lista numerada
# noterm 3       → apaga a nota de número 3
# noteclean      → apaga TODAS as notas (pede confirmação)
note() {
  local line n=0
  if (( $# > 0 )); then
    echo "$(date '+%Y-%m-%d %H:%M'): $*" >>! ~/notes.txt && echo "✅ Nota salva!"
    return
  fi
  echo "📝 Digite a nota e aperte Enter (linha vazia termina):"
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    echo "$(date '+%Y-%m-%d %H:%M'): $line" >>! ~/notes.txt
    (( n++ ))
  done
  if (( n > 0 )); then echo "✅ $n nota(s) salva(s)!"; else echo "Nada digitado — nada salvo."; fi
}
notes() {
  [[ -s ~/notes.txt ]] && cat -n ~/notes.txt || echo "Nenhuma nota ainda"
}
noterm() {
  if [[ ! -s ~/notes.txt ]]; then echo "Nenhuma nota ainda"; return 1; fi
  if [[ ! "$1" == <-> ]] || (( $1 < 1 || $1 > $(wc -l < ~/notes.txt) )); then
    echo "Uso: noterm <número> (veja a numeração com: notes)"; return 1
  fi
  sed -i "${1}d" ~/notes.txt
  echo "🗑️  Nota $1 apagada."
}
noteclean() {
  if [[ ! -s ~/notes.txt ]]; then echo "Nenhuma nota ainda"; return 0; fi
  read "resposta?Apagar TODAS as $(wc -l < ~/notes.txt) notas? (s/N) "
  if [[ "$resposta" == (s|S|sim|SIM) ]]; then
    rm -f ~/notes.txt && echo "✅ Todas as notas apagadas."
  else
    echo "Cancelado — nada foi apagado."
  fi
}
todo()  { echo "- [ ] $*" >>! ~/todo.txt && echo "TODO adicionado!"; }
todos() { cat ~/todo.txt 2>/dev/null || echo "Nenhum TODO ainda"; }
# 'done' é palavra reservada do zsh, por isso o nome 'tododone'
# usa grep -nF (match literal) + edita só a linha encontrada — barras, colchetes
# e outros caracteres especiais na tarefa não quebram mais o sed
tododone() {
  [[ -f ~/todo.txt ]] || { echo "Nenhum TODO ainda"; return 1; }
  local alvo="$*" n
  n=$(grep -Fn -- "- [ ] ${alvo}" ~/todo.txt | head -1 | cut -d: -f1)
  if [[ -z "$n" ]]; then
    echo "· tarefa não encontrada: '$alvo'"
    echo "  Veja as tarefas com: todos"
    return 1
  fi
  sed -i "${n}s|- \[ \]|- [x]|" ~/todo.txt && echo "✅ Marcado como feito: $alvo"
}
# cidade vai URL-encoded ANTES de ?format=3 — senão "?", "&" ou "/" na entrada
# sobrescrevem os parâmetros da query (mesmo truque usado em news/)
weather() {
  local cty
  cty=$(printf '%s' "${1:-}" | jq -Rr @uri 2>/dev/null) || cty="${1:-}"
  curl -s --max-time 8 "https://wttr.in/${cty}?format=3" 2>/dev/null || echo "sem conexão"
}
# lua — fase da lua em três modos:
#   lua           arte ANSI (cores no terminal, texto puro em pipe)
#   lua texto     só a linha textual: "Last Quarter - 1d 2h 36m"
#   lua emoji     🌕🌖🌗🌘🌑 de acordo com a fase
# O textual é extraído da própria arte do wttr.in (ela já vem com a fase e
# o tempo até a próxima). Se a extração falhar, cai no textual cru.
# compatibilidade: `moon` funciona como aliases de `lua`
moon() { lua "$@"; }

lua() {
  local raw clean fase1 proxima1 tempo1 emoji nome ilum prox_texto
  raw=$(curl -s --max-time 8 "https://wttr.in/Moon?format=3" 2>/dev/null)
  [[ -n "$raw" ]] || { echo "sem conexão"; return 1; }
  clean=$(printf '%s\n' "$raw" | sed 's/\x1b\[[0-9;]*m//g')
  # a arte do wttr.in traz 4 linhas de contexto textual:
  #   "Full Moon +"        (fase atual + sinal)
  #   "5 13:53:07"         (tempo até próxima: dias HH:MM:SS)
  #   "Last Quarter -"     (próxima fase)
  #   "1 2:23:47"          (tempo até a fase depois)
  fase1=$(printf '%s\n' "$clean" \
    | grep -oE '(Full Moon|Last Quarter|First Quarter|New Moon|Waxing (Crescent|Gibbous)|Waning (Crescent|Gibbous)) [+-]' \
    | head -1)
  proxima1=$(printf '%s\n' "$clean" \
    | grep -oE '(Full Moon|Last Quarter|First Quarter|New Moon|Waxing (Crescent|Gibbous)|Waning (Crescent|Gibbous)) [+-]' \
    | sed -n 2p)
  tempo1=$(printf '%s\n' "$clean" \
    | grep -oE '[0-9]+ [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)

  # emoji, nome em pt-BR e iluminação estimada por fase
  case "$fase1" in
    *"Full Moon"*)          emoji="🌕"; nome="Lua cheia";        ilum="100%" ;;
    *"Waxing Gibbous"*)     emoji="🌖"; nome="Lua gibosa";      ilum="75%"  ;;
    *"Last Quarter"*)       emoji="🌗"; nome="Quarto minguante";ilum="50%"  ;;
    *"Waning Crescent"*)    emoji="🌘"; nome="Lua minguante";   ilum="25%"  ;;
    *"New Moon"*)           emoji="🌑"; nome="Lua nova";        ilum="0%"   ;;
    *"Waxing Crescent"*)    emoji="🌒"; nome="Lua crescente";   ilum="25%"  ;;
    *"First Quarter"*)      emoji="🌒"; nome="Quarto crescente";ilum="50%"  ;;
    *)                      emoji="🌙"; nome="Lua";             ilum="?%"   ;;
  esac

  prox_texto=""
  [[ -n "$proxima1" && -n "$tempo1" ]] && {
    local dias="${tempo1%% *}" hhmmss="${tempo1#* }"
    prox_texto="Próxima: ${proxima1% *} em ${dias}d ${hhmmss%:*}"
  }

  case "${1:-}" in
    texto)
      [[ -n "$fase1" ]] && echo "$fase1" \
        || printf '%s\n' "$clean" | grep -iE 'moon|quarter' | head -1
      ;;
    emoji)
      echo "$emoji"
      ;;
    arte)
      # mantém cores se for terminal, strip se for pipe/script
      if [[ -t 1 ]]; then
        printf '%s\n' "$raw"
      else
        printf '%s\n' "$raw" | sed 's/\x1b\[[0-9;]*m//g'
      fi
      ;;
    *)
      # padrão: só texto
      echo "$emoji $nome"
      echo "Illuminação: $ilum"
      [[ -n "$prox_texto" ]] && echo "$prox_texto"
      ;;
  esac
}
# HN com títulos traduzidos para pt-BR (API MyMemory; fallback: título original)
# Corpo em subshell ( ) para os jobs em background NÃO poluírem o terminal
# com mensagens de job control ([1] 12345 / done ...)
news()  (
  i=0
  tmpd=$(mktemp -d) || return 1
  trap 'command rm -rf "$tmpd"' EXIT INT TERM
  curl -s --max-time 10 "https://hn.algolia.com/api/v1/search?tags=front_page" \
    | jq -r '.hits[:15][] | [.points, .num_comments, .title, (.url // "https://news.ycombinator.com/item?id=\(.objectID)")] | @tsv' \
    | while IFS=$'\t' read -r pts cm title url; do
        i=$((i+1))
        (
          trad=$(curl -s --max-time 8 "https://api.mymemory.translated.net/get?q=$(echo -n "$title" | jq -Rr @uri)&langpair=en|pt-BR" | jq -r '.responseData.translatedText // empty' 2>/dev/null)
          [[ -z "$trad" ]] && trad="$title"
          printf '%sp 💬%s  %s\n         🔗 %s\n' "$pts" "$cm" "$trad" "$url" > "$tmpd/$(printf '%02d' $i)"
        ) &
      done
  wait
  for f in $tmpd/*(N); do cat "$f"; done
)
crypto() { curl -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd,brl" | jq .; }
stocks() { curl -s "https://query1.finance.yahoo.com/v8/finance/chart/$1" | jq .chart.result[0].meta.regularMarketPrice; }
calc()  { python3 -c "print($*)"; }
timer() { echo "⏱️  Timer: ${1:-10}s (Ctrl+C para parar)"; sleep "${1:-10}"; echo "⏰ Tempo esgotado!"; }
stopwatch() { echo "Cronômetro iniciado. Enter para parar."; time read; }

# ------------------------------------------------------------
