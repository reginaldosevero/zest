#!/usr/bin/env bash
# zest :: smoke test — roda em qualquer distro com zsh (não precisa das ferramentas)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
FAIL=0

echo "🌶️  smoke test"

# 1) sintaxe de todos os módulos
for f in modules/*.zsh; do
  if zsh -n "$f" 2>/dev/null; then
    echo "  ✓ sintaxe: $f"
  else
    echo "  ✗ sintaxe: $f"; FAIL=1
  fi
done

# 2) todos os módulos carregam e as funções essenciais existem
#    (sem Oh My Zsh, sem ferramentas externas — as guardas é que fazem o trabalho)
export ZEST_QUIET=1
if zsh -c '
  for f in modules/*.zsh(N); do source "$f"; done
  missing=""
  for fn in sysinfo topmem topcpu note notes noterm noteclean todo todos tododone \
            weather moon news crypto stocks calc timer stopwatch \
            gci gpr gsync gstash gfiles gclean_branches \
            dsh dlogsall drmi dbuildpush dcp \
            nodeproject pyproject goproject rustproject \
            diskusage_dir ipinfo sysclean updateall \
            jsonfmt jsonmin json2yaml yaml2json countlines replace \
            portcheck download speedtest sslinfo backup_dir syncdir \
            ts2date date2ts worldtime procs git; do
    (( $+functions[$fn] )) || missing="$missing $fn"
  done
  if [[ -n "$missing" ]]; then echo "FALTANDO:$missing"; exit 1; fi
  echo "FUNCOES_OK"
' 2>/dev/null | grep -q FUNCOES_OK; then
  echo "  ✓ funções essenciais (50+, sem Oh My Zsh e sem ferramentas externas)"
else
  echo "  ✗ carregamento de funções"; FAIL=1
fi

# 3) o CLI responde
./bin/zest version | grep -q "zest " && echo "  ✓ CLI: zest version" || { echo "  ✗ CLI"; FAIL=1; }

echo "════════════════════"
(( FAIL == 0 )) && echo "✅ smoke test passou" || { echo "❌ smoke test falhou"; exit 1; }
