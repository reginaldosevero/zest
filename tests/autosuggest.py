#!/usr/bin/env python3
"""Prova visual de autossugestao: roda um zsh interativo num pseudo-terminal de
verdade e procura, nos bytes que iriam para a tela, o complemento vindo do
historico.

Por que isto existe: 'type _zsh_autosuggest_start' so prova que a funcao foi
carregada. O usuario nao ve funcao — ele ve cinza atras do cursor. Foi assim que
a autossugestao voltou a quebrar sem que nenhum teste percebesse: o plugin
existia em disco, a funcao existia, e a tela continuava vazia porque o Oh My Zsh
nao era carregado (o sweep tinha comentado 'source $ZSH/oh-my-zsh.sh').

Ler o PTY e exatamente o que o usuario ve. Sem fingimento.

Uso:  python3 tests/autosuggest.py [comando_para_digitAR] [treco_esperado]
Sai 0 quando a sugestao aparece na tela, 1 quando nao.
"""
import os
import pty
import select
import shutil
import sys
import time

DIGITAR = sys.argv[1] if len(sys.argv) > 1 else "git co"
ESPERADO = sys.argv[2] if len(sys.argv) > 2 else "mensagem-secreta-do-teste"
CHUNKS = []
fd = None


def drain(segundos):
    """Acumula tudo que o PTY emite durante N segundos."""
    fim = time.time() + segundos
    while time.time() < fim:
        lec, _, _ = select.select([fd], [], [], 0.2)
        if not lec:
            continue
        try:
            dados = os.read(fd, 65536)
        except OSError:
            return False
        if not dados:
            return False
        CHUNKS.append(dados)
    return True


def main():
    global fd
    env = dict(os.environ, TERM="xterm-256color", LANG="C.UTF-8",
               LINES="24", COLUMNS="80")
    zsh = os.environ.get("ZSH_BIN") or shutil.which("zsh") or "/usr/bin/zsh"

    # historico de verdade, escrito direto no HISTFILE do usuario
    hist = os.path.join(os.environ.get("HOME", "/root"), ".zsh_history")
    with open(hist, "a", encoding="utf-8") as fh:
        fh.write(': %d:0;git commit -m "%s"\n' % (int(time.time()), ESPERADO))

    pid, fd = pty.fork()
    if pid == 0:
        os.execve(zsh, [os.path.basename(zsh), "-i"], env)

    drain(3)
    os.write(fd, DIGITAR.encode())
    drain(3)
    os.write(fd, b"\x15\nexit\n")   # limpa a linha e sai
    drain(2)

    bruto = b"".join(CHUNKS).decode("utf-8", "replace")
    apareceu = ESPERADO in bruto
    print("AUTOSUGESTAO VISIVEL:",
          "apareceu na tela" if apareceu else "NAO apareceu")
    if not apareceu:
        print("--- cauda da tela ---")
        print(bruto[-500:].replace("\x1b", "<ESC>"))
    return 0 if apareceu else 1


if __name__ == "__main__":
    raise SystemExit(main())
