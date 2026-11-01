#!/usr/bin/env bash
# lib/zshrc.sh — mantém o bloco marcado do Zest no .zshrc (o install.sh usa)
#
# Por que mora num lib separado: o install.sh é monolítico e testar o bloco
# dentro dele exigiria rodar o instalador inteiro; aqui o smoke test exercita
# os três caminhos (sem bloco, bloco antigo, bloco novo) em milissegundos.
#
# A guarda anti-bash dentro do bloco existe por um erro real de container:
# 'source ~/.zshrc' numa sessão bash. O bash lê e executa um comando por vez,
# então o 'return' encerra o source ANTES de ele parsear o glob do zsh '(N)'
# da linha seguinte. Sem a guarda, o usuário leva, em vez de um aviso:
#   syntax error near unexpected token `('

zest_zshrc_block() {
  cat <<'ZESTEOF'

# >>> zest >>>
# Zest 🌶️ — o tempero do seu terminal (open source, MIT)
# Remoção limpa: rode o uninstall.sh do repositório
if [[ -n "${BASH_VERSION:-}" ]]; then
  echo 'Zest: .zshrc é arquivo do zsh — para ativar o Zest rode:  exec zsh' >&2
  return 0
fi
export ZEST_HOME="$HOME/.config/zest"
for _zmod in "$ZEST_HOME"/modules/*.zsh(N); do source "$_zmod"; done
unset _zmod
# <<< zest <<<
ZESTEOF
}

# O bloco já tem a guarda? Cuidado com o jeito óbvio ('sed | grep -q'): sob
# pipefail o grep -q fecha o pipe, o sed leva SIGPIPE e o retorno vira 141
# mesmo com o texto presente — o mesmo bug que derrubava o zest_pm_has.
zest_zshrc_guardada() {
  local trecho
  trecho=$(sed -n '/>>> zest >>>/,/<<< zest <<</p' "$1" 2>/dev/null)
  [[ "$trecho" == *'Zest: .zshrc é arquivo do zsh'* ]]
}

# Garante o bloco no arquivo SEM nunca tocar fora das marcações.
zest_zshrc_ensure() {
  local f="$1" abre fecha
  [[ -f "$f" ]] || : > "$f"
  # '|| true' nos dois greps: sem o bloco no arquivo o grep sai 1 e, sob o
  # 'set -euo pipefail' do install.sh, isso mataria o instalador inteiro num
  # container limpo — exatamente onde o arquivo nunca teve bloco
  abre=$(grep -n '>>> zest >>>' "$f" | head -n 1 | cut -d: -f1 || true)
  fecha=$(grep -n '<<< zest <<<' "$f" | tail -n 1 | cut -d: -f1 || true)

  if [[ -z "$abre" ]]; then
    zest_zshrc_block >> "$f"
    echo "✓ bloco acrescentado ao final do $f (nada do que já existia foi alterado)"
    return 0
  fi
  if zest_zshrc_guardada "$f"; then
    echo "✓ .zshrc já carrega o Zest (nada duplicado)"
    return 0
  fi
  # bloco antigo (sem a guarda): reescreve só o trecho entre as marcações.
  # Marcador de fechamento ausente ou fora de ordem = algo mexeu aí; não
  # adivinho, aviso e deixo o arquivo em paz.
  if [[ -z "$fecha" || "$fecha" -lt "$abre" ]]; then
    echo "⚠ bloco do Zest em $f sem o marcador '<<< zest <<<': deixei como está"
    return 0
  fi
  {
    head -n $((abre - 1)) "$f"
    zest_zshrc_block
    tail -n +$((fecha + 1)) "$f"
  } >"$f.zest-novo" || {
    echo "⚠ não consegui reescrever $f — deixei o original"
    rm -f "$f.zest-novo"
    return 0
  }
  if command -v zsh >/dev/null 2>&1 && ! zsh -n "$f.zest-novo" 2>/dev/null; then
    echo "⚠ o arquivo reescrito não passou no 'zsh -n' — mantive o original"
    rm -f "$f.zest-novo"
    return 0
  fi
  mv "$f.zest-novo" "$f"
  echo "✓ bloco do Zest atualizado com a guarda anti-bash (fora dele, nada mudou)"
}
