# zest :: 30-aliases — módulo do Zest (extraído e testado na prática)
#  ALIASES — Sistema (systemd/journalctl)
# ------------------------------------------------------------
alias sc='systemctl'
alias scs='systemctl status'
alias scr='sudo systemctl restart'
alias sce='sudo systemctl enable'
alias scd='sudo systemctl disable'
alias scst='sudo systemctl stop'
alias scsta='systemctl start'
alias scu='systemctl --user'
alias jc='journalctl'
alias jcf='journalctl -f'
alias jcu='journalctl -u'
alias jcb='journalctl -b'
alias jcp='journalctl -p err'

# ------------------------------------------------------------
#  ALIASES — Rede
# ------------------------------------------------------------
alias pingg='ping -c 5 8.8.8.8'
alias pingc='ping -c 5 1.1.1.1'
alias dnsflush='sudo systemd-resolve --flush-caches'
alias listen='ss -tulnp | grep LISTEN'
alias connections='ss -tan | grep ESTAB'
alias traceroute='traceroute -n'

geoip() { curl -s "https://ip-api.com/json/$1" | jq .; }   # geoip 8.8.8.8

# ------------------------------------------------------------
#  ALIASES — Banco de Dados
# ------------------------------------------------------------
alias psqlc='psql -U postgres'
alias mysqlc='mysql -u root -p'
alias redis='redis-cli'
alias pgdump='pg_dump'
alias pgrestore='pg_restore'

# ------------------------------------------------------------
#  ALIASES — SSH
# ------------------------------------------------------------
alias sshconfig='$EDITOR ~/.ssh/config'
alias sshkeys='ls -la ~/.ssh/'
alias sshagent='eval "$(ssh-agent -s)" && ssh-add'
alias sshcopy='ssh-copy-id'
alias sshgen='ssh-keygen -t ed25519 -C'

# ------------------------------------------------------------
#  ALIASES — Tmux
# ------------------------------------------------------------
alias t='tmux'
alias ta='tmux attach'
alias tat='tmux attach -t'
alias tls='tmux ls'
alias tns='tmux new -s'
alias tks='tmux kill-session -t'
alias tka='tmux kill-server'

# ------------------------------------------------------------
#  ALIASES — Editores
# ------------------------------------------------------------
alias v='vim'
alias nv='nvim'
code() { command code "$@" 2>/dev/null || command code-insiders "$@" 2>/dev/null || echo "VS Code não encontrado"; }
zed()  { command zed "$@" 2>/dev/null || echo "Zed não encontrado"; }

# ------------------------------------------------------------
#  ALIASES — Compressão
# ------------------------------------------------------------
alias tarz='tar -czf'
alias tarx='tar -xzf'
alias zipr='zip -r'
alias unzipq='unzip -q'

# ------------------------------------------------------------
#  ALIASES — Monitoramento
# ------------------------------------------------------------
alias top='command btop 2>/dev/null || command htop 2>/dev/null || command top'
alias meminfo='head -5 /proc/meminfo'
alias cpuinfo='lscpu'
command -v duf >/dev/null 2>&1 && alias df='duf'
alias diskcheck='ncdu'
procs()  { command procs "$@" 2>/dev/null || ps aux "$@"; }

# Versão legível para humanos: agrupa por programa, barra gráfica e cores
topmem() {
  echo "🧠 Quem mais usa MEMÓRIA (somado por programa):"
  echo ""
  local total; total=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
  ps -eo rss,args --no-headers \
    | awk '$0 ~ /eo rss,args/ {next} {n=split($2,a,"/"); mem[a[n]]+=$1} END {for (c in mem) printf "%d\t%s\n", mem[c], c}' \
    | sort -rn | head -10 \
    | awk -F'\t' -v total="$total" '
        function human(kb) {
          if (kb >= 1048576) return sprintf("%.1f GB", kb/1048576)
          if (kb >= 1024)    return sprintf("%d MB", kb/1024)
          return sprintf("%d KB", kb)
        }
        {
          pct = 100 * $1 / total
          full = int(pct / 5 + 0.5); if (full > 20) full = 20
          bar = ""
          for (i = 0; i < 20; i++) bar = bar (i < full ? "█" : "░")
          color = (pct > 60 ? "\033[31m" : (pct > 30 ? "\033[33m" : "\033[32m"))
          printf "  %-16s %8s  %s%s\033[0m %5.1f%%\n", substr($2,1,16), human($1), color, bar, pct
        }
        END { printf "\n  💡 RAM total da máquina: %s — para ver ao vivo: btop\n", human(total) }'
}

topcpu() {
  echo "🔥 Quem mais usa CPU (somado por programa):"
  echo ""
  ps -eo pcpu,args --no-headers \
    | awk '$0 ~ /eo pcpu,args/ {next} {n=split($2,a,"/"); cpu[a[n]]+=$1} END {for (c in cpu) printf "%.1f\t%s\n", cpu[c], c}' \
    | sort -rn | head -10 \
    | awk -F'\t' '
        {
          full = int($1 / 5 + 0.5); if (full > 20) full = 20
          bar = ""
          for (i = 0; i < 20; i++) bar = bar (i < full ? "█" : "░")
          color = ($1 > 80 ? "\033[31m" : ($1 > 40 ? "\033[33m" : "\033[32m"))
          printf "  %-16s %6.1f%%  %s%s\033[0m\n", substr($2,1,16), $1, color, bar
        }
        END { printf "\n  💡 %%CPU é a média desde que o programa abriu — uso em tempo real: btop\n" }'
}
portinfo() { sudo lsof -i :"$1" 2>/dev/null || ss -tulnp | grep ":$1"; }
alias temps='sensors 2>/dev/null || cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null'

# ------------------------------------------------------------
#  ALIASES — Desenvolvimento Web
# ------------------------------------------------------------
alias serve='python3 -m http.server 8000'
alias json='jq .'
alias curlj='curl -s -H "Accept: application/json" | jq .'
alias wgetm='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'

# ------------------------------------------------------------
#  ALIASES — Segurança / Hash / Encode
# ------------------------------------------------------------
alias ssl_check='openssl s_client -connect'
alias hash_md5='md5sum'
alias hash_sha256='sha256sum'
alias hash_sha512='sha512sum'
alias base64e='base64 -w 0'
alias base64d='base64 -d'
urlencode() { python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"; }
urldecode() { python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))" "$1"; }

# ------------------------------------------------------------
