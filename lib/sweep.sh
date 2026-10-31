#!/usr/bin/env bash
# zest :: lib/sweep — comenta 'source X' onde X é um caminho inexistente
#
# Um framework desinstalado (Oh My Zsh, Starship, zinit, p10k…) deixa a linha
# 'source $ZSH/oh-my-zsh.sh' no .zshrc, e o terminal quebra todo dia com
# "arquivo ou diretório inexistente". O Zest não pode mandar o usuário abrir
# o .zshrc na mão: ele varre sozinho e comenta as linhas cujo alvo não existe.
# Nunca apaga nada: só comenta, e o conteúdo do usuário continua intacto.
#
# Usado por:
#   install.sh  → passo 4b, antes de escrever o bloco do Zest
#
# Biblioteca: não altera opções globais do shell. Quem faz 'source' decide o
# próprio regime de erro — install.sh usa 'set -euo pipefail'.
#
# Três formatos: absoluto (/caminho), tilde (~/caminho) e variável
# ($ZSH/caminho). O 'eval' aqui só serve para EXPANDIR a variável na checagem
# de existência — o source em si nunca é executado pelo Zest.

# zest_sweep_orphans <arquivo>
zest_sweep_orphans() {
  local f="$1" tmp
  [[ -f "$f" ]] || return 0
  # procura 'source X' ou '. X' onde X tem barra (é caminho)
  if grep -qE '^[[:space:]]*(source|\.)[[:space:]]+[^;|&]*[/]' "$f"; then
    tmp="$(mktemp)"
    awk -v HOME="$HOME" -v ZSH="$ZSH" '
      /^[[:space:]]*(source|\.)[[:space:]]+[^;|&]*[/]/ {
        line = $0
        sub(/^[[:space:]]*(source|\.)[[:space:]]+/, "", line)
        sub(/[[:space:];|&]+.*$/, "", line)
        gsub(/^~/, HOME, line)
        gsub(/\$ZSH/, ZSH, line)
        gsub(/\$HOME/, HOME, line)
        # NÃO comenta frameworks principais conhecidos (mesmo se $ZSH vazio)
        if (line ~ /oh-my-zsh\.sh$|\.starship\.sh$|zinit\.zsh$|powerlevel10k\/powerlevel10k\.zsh-theme$/) {
          print
          next
        }
        if (system("test -e " line) != 0) {
          print "# [zest] source órfão: " line
          next
        }
        print
        next
      }
      { print }
    ' "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
    if grep -qE '^[[:space:]]*# \[zest\] source órfão' "$f"; then
      echo "· limpei referências órfãs em $f (frameworks desinstalados)"
    fi
  fi
}