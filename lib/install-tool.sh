#!/usr/bin/env bash
# zest :: install-tool — instala ferramentas CLI em ~/.local/bin, SEM root
# uso: install-tool.sh <nome> [nome2 ...]     (sem argumentos: lista disponíveis)
set -u
BIN="$HOME/.local/bin"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$BIN"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  A=amd64;  A64=x86_64 ;;
  aarch64) A=arm64;  A64=aarch64 ;;
  *) echo "❌ Arquitetura $ARCH não suportada ainda"; exit 1 ;;
esac

tag() {
  if command -v curl >/dev/null 2>&1; then
    curl -s --max-time 20 "https://api.github.com/repos/$1/releases/latest" | grep -oP '"tag_name": "\K[^"]+'
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- -T 20 "https://api.github.com/repos/$1/releases/latest" | grep -oP '"tag_name": "\K[^"]+'
  else
    echo "❌ Preciso de curl ou wget para consultar versões"; return 1
  fi
}
dl() {
  if command -v curl >/dev/null 2>&1; then curl -sL --max-time 300 -o "$T/$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q -T 300 -O "$T/$2" "$1"
  else echo "❌ Instale curl ou wget: sudo apt install -y curl"; return 1; fi
}

# instala <binário-final> — receitas por ferramenta
do_install() {
  case "$1" in
    fzf)      V=$(tag junegunn/fzf); dl "https://github.com/junegunn/fzf/releases/download/$V/fzf-${V#v}-linux_$A64.tar.gz" fzf.tgz && tar xzf "$T/fzf.tgz" -C "$T" fzf && mv "$T/fzf" "$BIN/fzf" ;;
    ripgrep)  V=$(tag BurntSushi/ripgrep); dl "https://github.com/BurntSushi/ripgrep/releases/download/$V/ripgrep-${V#v}-x86_64-unknown-linux-musl.tar.gz" rg.tgz && tar xzf "$T/rg.tgz" -C "$T" && mv "$T/ripgrep-${V#v}-x86_64-unknown-linux-musl/rg" "$BIN/rg" ;;
    fd)       V=$(tag sharkdp/fd); dl "https://github.com/sharkdp/fd/releases/download/$V/fd-${V}-x86_64-unknown-linux-gnu.tar.gz" fd.tgz && tar xzf "$T/fd.tgz" -C "$T" && mv "$T/fd-${V}-x86_64-unknown-linux-gnu/fd" "$BIN/fd" ;;
    bat)      V=$(tag sharkdp/bat); dl "https://github.com/sharkdp/bat/releases/download/$V/bat-${V}-x86_64-unknown-linux-gnu.tar.gz" bat.tgz && tar xzf "$T/bat.tgz" -C "$T" && mv "$T/bat-${V}-x86_64-unknown-linux-gnu/bat" "$BIN/bat" ;;
    eza)      dl "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" eza.tgz && tar xzf "$T/eza.tgz" -C "$T" && mv "$T/eza" "$BIN/eza" ;;
    delta)    V=$(tag dandavison/delta); dl "https://github.com/dandavison/delta/releases/download/$V/delta-${V#v}-x86_64-unknown-linux-gnu.tar.gz" delta.tgz && tar xzf "$T/delta.tgz" -C "$T" && mv "$T/delta-${V#v}-x86_64-unknown-linux-gnu/delta" "$BIN/delta" ;;
    lazygit)  V=$(tag jesseduffield/lazygit); dl "https://github.com/jesseduffield/lazygit/releases/download/$V/lazygit_${V#v}_Linux_x86_64.tar.gz" lg.tgz && tar xzf "$T/lg.tgz" -C "$T" lazygit && mv "$T/lazygit" "$BIN/lazygit" ;;
    duf)      V=$(tag muesli/duf); dl "https://github.com/muesli/duf/releases/download/$V/duf_${V}_linux_$A64.tar.gz" duf.tgz && tar xzf "$T/duf.tgz" -C "$T" duf && mv "$T/duf" "$BIN/duf" ;;
    jq)       dl "https://github.com/jqlang/jq/releases/latest/download/jq-linux-$A" jq && chmod +x "$T/jq" && mv "$T/jq" "$BIN/jq" ;;
    yq)       dl "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$A" yq && chmod +x "$T/yq" && mv "$T/yq" "$BIN/yq" ;;
    direnv)   dl "https://github.com/direnv/direnv/releases/latest/download/direnv.linux-$A" direnv && chmod +x "$T/direnv" && mv "$T/direnv" "$BIN/direnv" ;;
    tldr)     dl "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-$A64" tldr && chmod +x "$T/tldr" && mv "$T/tldr" "$BIN/tldr" && "$BIN/tldr" --update ;;
    zoxide)   curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null 2>&1 ;;
    atuin)    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | bash >/dev/null 2>&1 ;;
    mise)     curl -s https://mise.run | bash >/dev/null 2>&1 ;;
    thefuck)  command -v uv >/dev/null 2>&1 && uv tool install thefuck --python 3.11 --force >/dev/null 2>&1 ;;
    *) echo "❌ Ferramenta desconhecida: $1 (disponíveis: $(available | tr '\n' ' '))"; return 1 ;;
  esac
}

available() { printf '%s\n' fzf ripgrep fd bat eza delta lazygit duf jq yq direnv tldr zoxide atuin mise thefuck; }

[[ $# -eq 0 ]] && { echo "Uso: install-tool.sh <ferramenta...>"; echo "Disponíveis: $(available | tr '\n' ' ')"; exit 0; }

FAIL=0
for tool in "$@"; do
  printf '→ %s: ' "$tool"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "já instalado ✓"
    continue
  fi
  if do_install "$tool"; then
    echo "instalado ✓"
  else
    echo "FALHOU ✗"
    FAIL=1
  fi
done
exit $FAIL
