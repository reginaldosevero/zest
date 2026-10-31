#!/usr/bin/env bash
# zest :: lib/install-helpers — portagem segura de binário (download → verificação → mv)
#
# Biblioteca: não altera opções globais do shell. Quem faz 'source' decide o
# próprio regime de erro (install-tool.sh usa 'set -u').
#
# Usado por:
#   lib/install-tool.sh → as 17 receitas de ferramenta
#   tests/smoke.sh      → os testes de unpack_bin/finish_bin usam a função REAL,
#                         não uma cópia (cópias divergem — ver CHANGELOG 0.2.0,
#                         quando um zest_pkg antigo sobreviveu e passou por cima)
#
# SEGURANÇA
#  - só HTTPS (curl --proto '=https' / wget --https-only)
#  - nada de "curl | sh": nada daqui executa o que baixou
#  - checksum sha256 conferido contra o digest oficial do GitHub quando existir
#  - validação de ELF: página de erro/HTML nunca vira "binário"

# $T (dir temporário) e $BIN (~/.local/bin) vêm de quem nos carrega.

# check_elf <arquivo> — é um binário ELF de verdade?
check_elf() {
  [[ "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "7f454c46" ]]
}

# unpack_bin <tgz> <nome-do-binário> — extrai o tarball INTEIRO em diretório
# próprio e imprime o caminho real do binário.
#
# NUNCA assuma o caminho interno do tarball: os upstreams reorganizam os
# arquivos entre releases sem avisar. O atuin passou a vir dentro de
# "atuin-<triple>/" e um `tar … atuin` fixo quebrou o install em campo com o
# checksum conferindo — a impressão era de download corrompido, era layout.
# varrer a árvore atrás de um ELF com o nome certo sobrevive a qualquer reorganização.
#
# Extrai em $T/x-XXXXXX (um por chamada): instalar mais de uma ferramenta na
# mesma execução compartilharia arquivos, e o 'find' poderia devolver o binário
# de um tarball anterior. O trap de quem nos carrega apaga $T no fim.
unpack_bin() {
  local tgz="$1" want="$2" dir f
  dir=$(mktemp -d "$T/x-XXXXXX") || { echo "   ❌ sem espaço para extrair" >&2; return 1; }
  tar xzf "$tgz" -C "$dir" 2>/dev/null || { echo "   ❌ falha ao extrair $tgz" >&2; return 1; }
  while IFS= read -r f; do
    # só aceita ELF: tarball traz README, man page e completion com nomes parecidos
    if check_elf "$f"; then printf '%s\n' "$f"; return 0; fi
  done < <(find "$dir" -type f -name "$want")
  echo "   ❌ '$want' não apareceu dentro do tarball (layout do asset mudou?)" >&2
  return 1
}

# finish_bin <arquivo> <destino> — última portagem: ELF verdadeiro → +x → mv
finish_bin() {
  [[ -n "${1:-}" ]] || return 1
  check_elf "$1" || { echo "   ❌ não é um binário ELF: $1" >&2; return 1; }
  chmod +x "$1" && mv "$1" "$BIN/$2"
}
