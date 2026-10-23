# zest :: 49-utils — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Rede
# ------------------------------------------------------------
portcheck() {
  timeout 2 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && echo "✅ Porta $2 aberta em $1" || echo "❌ Porta $2 fechada em $1"
}

download() { wget --show-progress -O "${2:-$(basename "$1")}" "$1"; }

speedtest() {
  curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
}

sslinfo() {
  echo | openssl s_client -servername "$1" -connect "$1:443" 2>/dev/null | openssl x509 -noout -dates -subject -issuer
}

# ------------------------------------------------------------
#  FUNÇÕES — Backup e Sync
# ------------------------------------------------------------
backup_dir() {
  local src="$1"
  local dest="${2:-$HOME/backups}"
  local name ts
  name=$(basename "$src")
  ts=$(date +%Y%m%d_%H%M%S)
  mkdir -p "$dest"
  tar -czf "$dest/${name}_${ts}.tar.gz" "$src"
  echo "✅ Backup criado: $dest/${name}_${ts}.tar.gz"
}

syncdir() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Uso: syncdir <origem> <destino>"
    echo "Ex.: syncdir ~/Documentos /mnt/backup"
    echo ""
    echo "Dica: COM a barra no fim da origem ('pasta/') copia só o CONTEÚDO;"
    echo "      SEM a barra ('pasta') copia a pasta inteira."
    return 1
  fi
  if [[ ! -e "$1" ]]; then
    echo "❌ A origem '$1' não existe."
    echo "   Verifique o nome (TAB autocompleta caminhos). Pastas na sua home:"
    ls -d ~/*/ 2>/dev/null | head -10
    return 1
  fi
  rsync -avz --progress "$1" "$2"
}

# ------------------------------------------------------------
#  FUNÇÕES — Data e Hora
# ------------------------------------------------------------
ts2date() { date -d "@$1" "+%Y-%m-%d %H:%M:%S"; }
date2ts() { date -d "$1" +%s; }

worldtime() {
  for tz in "America/Sao_Paulo" "America/New_York" "Europe/London" "Europe/Paris" "Asia/Tokyo" "Asia/Shanghai" "Australia/Sydney"; do
    printf "%-22s %s\n" "$tz" "$(TZ=$tz date '+%H:%M %Z')"
  done
}

# ------------------------------------------------------------
