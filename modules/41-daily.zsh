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
tododone() { sed -i "s/- \[ \] $*/- [x] $*/" ~/todo.txt && echo "Marcado como feito!"; }
weather() { curl -s "https://wttr.in/${1:-}?format=3" 2>/dev/null || echo "sem conexão"; }
moon()  { curl -s "https://wttr.in/Moon?format=3" 2>/dev/null; }
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
