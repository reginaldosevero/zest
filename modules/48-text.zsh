# zest :: 48-text — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Texto e Conversão
# ------------------------------------------------------------
jsonfmt() { jq . "$1"; }
jsonmin() { jq -c . "$1"; }
json2yaml() { command -v yq >/dev/null 2>&1 && yq -P "$1" || echo "yq não instalado"; }
yaml2json() { command -v yq >/dev/null 2>&1 && yq -o=json "$1" || echo "yq não instalado"; }
countlines() { command -v tokei >/dev/null 2>&1 && tokei "${1:-.}" || echo "tokei não instalado"; }

spell() {
  local file="${1:?Uso: spell <arquivo>}"
  [[ -f "$file" ]] || { echo "· arquivo não encontrado: $file"; return 1; }
  aspell -c "$file"
}

replace() {
  local search="$1" repl="$2" ext="${3:-*}"
  grep -rl "$search" --include="*.$ext" . | xargs -r sed -i "s/$search/$repl/g"
  echo "✅ Substituído '$search' por '$repl' em arquivos *.$ext"
}

# ------------------------------------------------------------
