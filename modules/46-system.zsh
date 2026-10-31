# zest :: 46-system — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Sistema
# ------------------------------------------------------------
diskusage_dir() { du -sh "${1:-.}"/* 2>/dev/null | sort -rh | head -20; }

ipinfo() {
  echo "🌐 IP Público: $(curl -s --max-time 5 https://ifconfig.me)"
  echo "🏠 IP Local:   $(hostname -I | awk '{print $1}')"
  echo "📡 Gateway:    $(ip route | grep default | awk '{print $3}')"
  echo "🔗 DNS:        $(grep nameserver /etc/resolv.conf | head -1)"
}

sysinfo() {
  local os kernel model cores threads up mt ma st sf dt du
  os=$(grep -oP '(?<=PRETTY_NAME=").*(?=")' /etc/os-release)
  kernel=$(uname -r)
  model=$(LC_ALL=C lscpu | awk -F': +' '/Model name/ {print $2; exit}' | sed -E 's/\((R|TM)\)//g; s/ CPU @/ @/')
  cores=$(LC_ALL=C lscpu | awk -F': +' '/^Core\(s\) per socket/ {print $2; exit}')
  threads=$(LC_ALL=C lscpu | awk -F': +' '/^CPU\(s\):/ {print $2; exit}')
  up=$(awk '{printf "%dh%02dmin", $1/3600, ($1%3600)/60}' /proc/uptime)
  read -r mt ma st sf <<< "$(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} /^SwapTotal/{s=$2} /^SwapFree/{f=$2} END {print t, a, s, f}' /proc/meminfo)"
  read -r dt du <<< "$(command df -B1 / | awk 'NR==2 {print $2, $3}')"

  echo "🖥️  SISTEMA"
  echo "   $os · kernel $kernel"
  echo ""
  echo "🧠  PROCESSADOR"
  echo "   $model"
  echo "   ${cores} núcleos · ${threads} threads"
  echo ""
  echo "💾  MEMÓRIA E DISCO"
  awk -v mt="$mt" -v ma="$ma" -v st="$st" -v sf="$sf" -v dtb="$dt" -v dub="$du" '
    function human(kb) {
      if (kb >= 1048576) return sprintf("%.1f GB", kb/1048576)
      if (kb >= 1024)    return sprintf("%d MB", kb/1024)
      return sprintf("%d KB", kb)
    }
    function pbar(pct) {
      full = int(pct/5 + 0.5); if (full > 20) full = 20
      bar = ""
      for (i = 0; i < 20; i++) bar = bar (i < full ? "█" : "░")
      color = (pct > 85 ? "\033[31m" : (pct > 60 ? "\033[33m" : "\033[32m"))
      return color bar "\033[0m"
    }
    BEGIN {
      used = mt - ma; pct = 100 * used / mt
      printf "   RAM:   %8s de %8s  %s %5.1f%%\n", human(used), human(mt), pbar(pct), pct
      if (st + 0 > 0) {
        u = st - sf; p2 = 100 * u / st
        printf "   Swap:  %8s de %8s  %s %5.1f%%\n", human(u), human(st), pbar(p2), p2
      }
      pct3 = 100 * dub / dtb
      printf "   Disco: %8s de %8s  %s %5.1f%%\n", human(dub/1024), human(dtb/1024), pbar(pct3), pct3
    }'
  echo ""
  echo "⏱️  LIGADO HÁ $up"
}

sysclean() {
  # nada de 'sudo apt ...' fixo: a limpeza segue o gerenciador da máquina
  local pm
  pm=$(_zest-pm-detect)
  if [[ -n "$pm" ]]; then
    echo "🧹 Limpeza de pacotes via $pm"
    _zest-pm-autoremove "$pm"
    _zest-pm-clean "$pm"
  else
    echo "· nenhum gerenciador de pacotes conhecido (apt/dnf/pacman/zypper/apk) — pulando"
  fi

  # journalctl só existe em sistema com systemd (Alpine/OpenRC não tem)
  if command -v journalctl >/dev/null 2>&1; then
    _zest-sudo journalctl --vacuum-time=7d
  else
    echo "· journalctl indisponível (sem systemd) — pulando logs"
  fi

  # (N) evita o erro de NOMATCH; sem arquivos, nem chamamos o rm
  local -a thumbs
  thumbs=("$HOME"/.cache/thumbnails/*(N))
  (( ${#thumbs} )) && rm -rf -- "${thumbs[@]}"
  echo "✅ Sistema limpo!"
}

updateall() {
  echo "🔄 Atualizando TUDO — o que não estiver instalado é pulado"
  echo "════════════════════════════════════════════════════"

  # 1) Sistema — o gerenciador é o da SUA distro, não um apt fixo
  echo ""
  local PM_SISTEMA
  PM_SISTEMA=$(_zest-pm-detect)
  if [[ -n "$PM_SISTEMA" ]]; then
    echo "📦 1/12 · Sistema ($PM_SISTEMA)"
    _zest-pm-update  "$PM_SISTEMA" || true
    _zest-pm-upgrade "$PM_SISTEMA" || true
    _zest-pm-autoremove "$PM_SISTEMA" || true
  else
    echo "📦 1/12 · Sistema — nenhum gerenciador conhecido (apt/dnf/pacman/zypper/apk), pulando"
  fi

  # 2) Oh My Zsh + plugins (pulam se não houver Oh My Zsh)
  if (( $+functions[omz] )); then
    omz update
    for dir in ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/*/; do
      [ -d "$dir/.git" ] && git -C "$dir" pull --quiet
    done
  else
    echo "   Oh My Zsh não encontrado — pulando"
  fi

  # 3) mise (node, python, go… instalados via mise)
  echo ""
  echo "🧰 3/12 · mise"
  if command -v mise >/dev/null 2>&1; then mise upgrade; else echo "   não instalado — pulando"; fi

  # 4) uv (ferramentas Python via uv)
  echo ""
  echo "🐍 4/12 · uv"
  if command -v uv >/dev/null 2>&1; then uv tool upgrade --all; else echo "   não instalado — pulando"; fi

  # 5) pipx (aplicativos Python)
  echo ""
  echo "🐍 5/12 · pipx"
  if command -v pipx >/dev/null 2>&1; then pipx upgrade-all; else echo "   não instalado — pulando"; fi

  # 6) pip (o próprio pip)
  echo ""
  echo "🐍 6/12 · pip"
  if command -v pip3 >/dev/null 2>&1; then
    python3 -m pip install --upgrade pip --quiet 2>/dev/null || echo "   pip do sistema é protegido pela distro (PEP 668) — use uv/pipx para ferramentas"
  else
    echo "   não instalado — pulando"
  fi

  # 7) Flatpak (aplicativos)
  echo ""
  echo "📦 7/12 · Flatpak"
  if command -v flatpak >/dev/null 2>&1; then flatpak update -y; else echo "   não instalado — pulando"; fi

  # 8) Snap (aplicativos)
  echo ""
  echo "📦 8/12 · Snap"
  if command -v snap >/dev/null 2>&1; then _zest-sudo snap refresh; else echo "   não instalado — pulando"; fi

  # 9) npm (pacotes globais)
  echo ""
  echo "🟩 9/12 · npm"
  if command -v npm >/dev/null 2>&1; then
    if [[ -w "$(npm prefix -g)" ]]; then
      npm update -g
    else
      echo "   (pacotes globais no sistema — elevando privilégio)"
      _zest-sudo npm update -g
    fi
  else
    echo "   não instalado — pulando"
  fi

  # 10) rustup (ecossistema Rust)
  echo ""
  echo "🦀 10/12 · rustup"
  if command -v rustup >/dev/null 2>&1; then rustup update; else echo "   não instalado — pulando"; fi

  # 11) OpenCode (a IA que você está usando agora)
  echo ""
  echo "🤖 11/12 · OpenCode"
  if command -v opencode >/dev/null 2>&1; then opencode upgrade; else echo "   não instalado — pulando"; fi

  # 12) Cache do tldr
  echo ""
  echo "📖 12/12 · tldr (páginas de ajuda)"
  if command -v tldr >/dev/null 2>&1; then tldr --update; else echo "   não instalado — pulando"; fi

  echo ""
  echo "════════════════════════════════════════════════════"
  echo "✅ Tudo atualizado!"
}

# ------------------------------------------------------------
