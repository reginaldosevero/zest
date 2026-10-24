# zest :: 49-utils — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Rede
# ------------------------------------------------------------
portcheck() {
  if [[ -z "$1" || -z "$2" ]]; then echo "Uso: portcheck <host> <porta>"; return 1; fi
  # host/porta passam como ARGUMENTOS ($0/$1 do bash -c), nunca interpolados no código
  timeout 2 bash -c 'echo > /dev/tcp/"$0"/"$1"' "$1" "$2" 2>/dev/null \
    && echo "✅ Porta $2 aberta em $1" || echo "❌ Porta $2 fechada em $1"
}

download() {
  case "$1" in
    https://*|http://*) ;;
    *) echo "Uso: download <url-http(s)> [arquivo]"; return 1 ;;
  esac
  wget --show-progress -O "${2:-$(basename -- "$1")}" "$1"
}

speedtest() {
  command -v curl >/dev/null 2>&1 || { echo "curl não instalado"; return 1; }
  local bps
  echo "⏱️  Medindo download (25 MB, Cloudflare)…"
  # medição pura: nenhum código remoto é baixado ou executado
  bps=$(curl -s --fail --proto '=https' --tlsv1.2 --max-time 60 -o /dev/null \
        -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=26214400') || {
    echo "❌ Não consegui medir (sem conexão?)"; return 1; }
  awk -v b="$bps" 'BEGIN{ printf "⬇️  Download: %.1f Mbps (%.1f MB/s)\n", b*8/1e6, b/1e6 }'
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
  if [[ -z "$src" || ! -e "$src" ]]; then
    echo "Uso: backup_dir <pasta-ou-arquivo> [destino]"; return 1
  fi
  name=$(basename -- "$src")
  ts=$(date +%Y%m%d_%H%M%S)
  mkdir -p -- "$dest"
  # '--' encerra as opções: um caminho começando com '-' nunca vira flag do tar
  tar -czf "$dest/${name}_${ts}.tar.gz" -- "$src"
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
  if [[ "$1" == -* || "$2" == -* ]]; then
    echo "❌ Caminhos começando com '-' não são aceitos (proteção contra opções injetadas)."
    return 1
  fi
  if [[ ! -e "$1" ]]; then
    echo "❌ A origem '$1' não existe."
    echo "   Verifique o nome (TAB autocompleta caminhos). Pastas na sua home:"
    ls -d ~/*/ 2>/dev/null | head -10
    return 1
  fi
  rsync -avz --progress -- "$1" "$2"
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
