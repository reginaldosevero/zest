# zest :: 50-history — gerenciar o histórico do shell
# Ctrl+R busca; aqui você APAGA o que quiser:
#   histnum               lista as últimas linhas numeradas
#   histsed N             apaga UMA linha pelo número
#   histdel <padrão>      apaga TODAS as linhas que contêm o padrão
#   histclear             apaga TUDO (com confirmação)
# Extras: histsearch · histcount · histsize · histclean
# ------------------------------------------------------------
# Nota: a numeração é a LINHA do arquivo (HISTFILE), não o número
# que o zsh mostra em `history` — é o que permite apagar com precisão.
# ------------------------------------------------------------

# histnum [N] — lista as últimas N linhas do histórico numeradas
histnum() {
  local n="${1:-30}"
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "Uso: histnum [N] (padrão: 30)"; return 1; }
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico ($hf)"; return 1; }
  local total shown start lines i line
  total=$(wc -l < "$hf")
  (( total > 0 )) || { echo "· histórico vazio"; return 1; }
  # quantas linhas realmente cabem (n pode ser maior que total)
  shown=$(( n < total ? n : total ))
  start=$(( total - shown + 1 ))   # número da primeira linha exibida (>= 1)
  lines=$(tail -n "$shown" "$hf")
  i=$start
  while IFS= read -r line; do
    printf '%6d  %s\n' "$i" "$line"
    i=$((i + 1))
  done <<< "$lines"
  echo "— fim (mostradas $shown de $total linhas; use histsed N para apagar) —"
}

# histsed N — apaga a linha de número N (veja os números com histnum)
histsed() {
  local n="$1"
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "Uso: histsed N   (N = número do histnum)"; return 1; }
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico"; return 1; }
  local total vitima conf
  total=$(wc -l < "$hf")
  (( n >= 1 && n <= total )) || { echo "· linha $n fora do intervalo (1..$total)"; return 1; }
  vitima=$(sed -n "${n}p" "$hf")
  echo "Vai apagar:  $vitima"
  read "conf?Confirma? (s/N) "
  [[ "$conf" == (s|S|sim|SIM|y|Y|yes|YES) ]] || { echo "Cancelado — nada foi apagado."; return 1; }
  # sed puro (sem -i): funciona até em busybox (Alpine)
  sed "${n}d" "$hf" > "${hf}.tmp.$$" && mv "${hf}.tmp.$$" "$hf"
  chmod 600 "$hf" 2>/dev/null || true
  fc -R 2>/dev/null || true
  echo "✅ linha $n apagada"
}

# histdel <padrão> — apaga TODAS as linhas que contêm o padrão (texto literal)
histdel() {
  local pat="$1"
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ -n "$pat" ]] || { echo "Uso: histdel <padrão>   Ex.: histdel 'senha'"; return 1; }
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico ($hf)"; return 1; }
  local antes depois rem
  antes=$(wc -l < "$hf")
  # -F = match literal (não interpreta regex); -a = binário pode ter \0
  grep -aFv -- "$pat" "$hf" > "${hf}.tmp.$$" && mv "${hf}.tmp.$$" "$hf"
  chmod 600 "$hf" 2>/dev/null || true
  depois=$(wc -l < "$hf")
  fc -R 2>/dev/null || true
  rem=$((antes - depois))
  if (( rem > 0 )); then
    echo "✅ apagadas $rem linha(s) contendo '$pat'"
  else
    echo "· nada continha '$pat' — histórico intacto"
  fi
}

# histclear — apaga TODO o histórico (pede confirmação)
histclear() {
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico"; return 1; }
  local n conf
  n=$(wc -l < "$hf")
  (( n > 0 )) || { echo "· histórico já está vazio"; return 0; }
  read "conf?⚠️  Apagar TODAS as $n linhas do histórico? (s/N) "
  [[ "$conf" == (s|S|sim|SIM|y|Y|yes|YES) ]] || { echo "Cancelado — nada foi apagado."; return 1; }
  : > "$hf"
  chmod 600 "$hf" 2>/dev/null || true
  fc -p 2>/dev/null || true   # zsh: recomeça histórico vazio na sessão atual
  echo "✅ Histórico apagado ($n linhas)."
}

# histsearch <padrão> — mostra as linhas do histórico que contêm o padrão
histsearch() {
  local pat="$1"
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ -n "$pat" ]] || { echo "Uso: histsearch <padrão>"; return 1; }
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico"; return 1; }
  grep -anF -- "$pat" "$hf" | head -30
}

# histcount — quantas linhas tem no histórico
histcount() {
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  if [[ -f "$hf" ]]; then
    printf "📜 %s linhas em %s\n" "$(wc -l < "$hf")" "$hf"
  else
    echo "· nenhum arquivo de histórico"
  fi
}

# histsize <n> — limita o histórico às N linhas mais recentes
histsize() {
  local n="${1:-500}"
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "Uso: histsize <número-de-linhas>"; return 1; }
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico"; return 1; }
  local antes depois
  antes=$(wc -l < "$hf")
  tail -n "$n" "$hf" > "${hf}.tmp.$$" && mv "${hf}.tmp.$$" "$hf"
  chmod 600 "$hf" 2>/dev/null || true
  depois=$(wc -l < "$hf")
  echo "✅ Histórico reduzido: $antes → $depois linhas (mantidas as $n mais recentes)"
}

# histclean — apaga linhas vazias e duplicatas (mantém a última ocorrência)
histclean() {
  local hf="${HISTFILE:-$HOME/.zsh_history}"
  [[ -f "$hf" ]] || { echo "· nenhum arquivo de histórico"; return 1; }
  local antes depois
  antes=$(wc -l < "$hf")
  awk 'NF' "$hf" | tac | awk '!seen[$0]++' | tac > "${hf}.tmp.$$" \
    && mv "${hf}.tmp.$$" "$hf"
  chmod 600 "$hf" 2>/dev/null || true
  depois=$(wc -l < "$hf")
  echo "✅ Compactado: $antes → $depois linhas (duplicatas e vazias removidas)"
}
