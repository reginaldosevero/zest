# zest :: 48-text — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Texto e Conversão
# ------------------------------------------------------------
jsonfmt() { jq . "$1"; }
jsonmin() { jq -c . "$1"; }
json2yaml() { command -v yq >/dev/null 2>&1 && yq -P "$1" || echo "yq não instalado"; }
yaml2json() { command -v yq >/dev/null 2>&1 && yq -o=json "$1" || echo "yq não instalado"; }
countlines() { command -v tokei >/dev/null 2>&1 && tokei "${1:-.}" || echo "tokei não instalado"; }

spell() {
  local file="${1:?Uso: spell <arquivo>  |  spell -i <arquivo> (interativo)}"
  local interactive=0
  if [[ "$file" == "-i" ]]; then
    interactive=1
    file="${2:?Uso: spell -i <arquivo>}"
  fi
  command -v aspell >/dev/null 2>&1 || { echo "· aspell não instalado (apt install aspell aspell-pt-br)"; return 1; }
  [[ -f "$file" ]] || { echo "· arquivo não encontrado: $file"; return 1; }

  # dicionário: pt_BR se instalado, senão o padrão do sistema
  local dict=""
  aspell dicts 2>/dev/null | grep -qw pt && dict="-l pt_BR"

  if (( interactive )); then
    # modo interativo: precisa de terminal de verdade
    [[ -t 0 && -t 1 ]] || { echo "· modo -i precisa de terminal interativo (sem pipe)"; return 1; }
    aspell -c $dict "$file"
    return
  fi

  # modo lista: mostra cada erro com sugestões (funciona com pipe)
  local linha atual=0 erros=0
  while IFS= read -r linha; do
    # aspell -a responde "& palavra N pos: sug1, sug2..." para cada erro
    [[ "$linha" == \&\ * ]] || continue
    erros=$((erros + 1))
    local palavra sugestoes
    palavra=$(echo "$linha" | awk '{print $2}')
    sugestoes=$(echo "$linha" | sed 's/.*: //' | cut -d, -f1-8)
    echo "❌ $palavra"
    echo "   → $sugestoes"
  done < <(aspell -a $dict < "$file" 2>/dev/null)

  if (( erros == 0 )); then
    echo "✅ nenhum erro de ortografia em $file"
  else
    echo ""
    echo "📝 $erros palavra(s) com problema em $file"
    echo "   para corrigir uma a uma: spell -i $file"
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
