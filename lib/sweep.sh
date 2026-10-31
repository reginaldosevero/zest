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
# próprio regime de erro — install.sh usa 'set -euo pipefail'. Por isso NENHUMA
# variável aqui é lida crua: sempre '${VAR:-padrão}', senão um '$ZSH' inexistente
# aborta a instalação inteira (foi o bug que sumia com os plugins).
#
# Regra central: comentar é uma intervenção. Só comento quando TENHO CERTEZA de
# que o alvo não existe — isto é, quando consegui resolver o caminho por inteiro.
# Se sobrou '$' (variável que não conheço) ou '*' (glob), a linha é deixada em
# paz. Falso positivo quebra o shell do usuário; falso negativo é só uma linha
# morta a mais, e é o erro que eu escolho cometer.

# zest_sweep_orphans <arquivo>
zest_sweep_orphans() {
  local f="$1" tmp
  [[ -f "$f" ]] || return 0
  # procura 'source X' ou '. X' onde X tem barra (é caminho)
  if grep -qE '^[[:space:]]*(source|\.)[[:space:]]+[^;|&]*[/]' "$f"; then
    tmp="$(mktemp)" || return 0
    # Caminhos que sei resolver. $ZSH é o diretório do Oh My Zsh; quem roda o
    # sweep sem exportar ZSH (install.sh, CI, bash) recebe o caminho canônico.
    local _zsh="${ZSH:-$HOME/.oh-my-zsh}"
    awk -v HOME="$HOME" -v ZSH="$_zsh" '
      /^[[:space:]]*(source|\.)[[:space:]]+[^;|&]*[/]/ {
        line = $0
        sub(/^[[:space:]]*(source|\.)[[:space:]]+/, "", line)
        sub(/[[:space:];|&|]+.*$/, "", line)
        gsub(/^"|"$/, "", line)
        gsub(/^'\''|'\''$/, "", line)
        path = line
        gsub(/^~/, HOME, path)
        gsub(/\$\{?ZSH\}?/, ZSH, path)
        gsub(/\$\{?HOME\}?/, HOME, path)
        gsub(/\$\{?USERPROFILE\}?/, HOME, path)
        # resolvi tudo? sobrou $ ou glob => não sei o alvo => não toco.
        if (path ~ /[$*?]/) { print; next }
        # frameworks principais: nunca comentar, mesmo se algo der errado.
        if (path ~ /(oh-my-zsh\.sh|\.starship\.sh|zinit\.zsh|antidote\.zsh|powerlevel10k\.zsh-theme|oh-my-posh\.zsh)$/) {
          print; next
        }
        if (system("test -e " quote(path)) != 0) {
          print "# [zest] source órfão (arquivo não existe): " line
          next
        }
        print
        next
      }
      { print }
      function quote(s) { gsub(/'\''/, "'\''\\\\'\'''\''", s); return "\047" s "\047" }
    ' "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
    if grep -qE '^[[:space:]]*# \[zest\] source órfão' "$f"; then
      echo "· limpei referências órfãs em $f (frameworks desinstalados)"
    fi
  fi
}
