# Changelog

## 0.1.8 — 2026-10-26

### Novo
- **Módulo de histórico** (`modules/50-history.zsh`): `histnum` (lista numerada), `histsed N` (apaga uma linha com confirmação), `histdel <padrão>` (apaga todas as linhas com o padrão), `histclear` (apaga tudo), `histsearch`, `histcount`, `histsize`, `histclean` — apagar o histórico que você quiser, exatamente
- **Corretor ortográfico** (`spell`): `spell arquivo` lista erros com sugestões (aspell pt_BR), `spell -` lê stdin, `spell -x` lê o clipboard, `spell -i` corrige interativo — mais `correct`, que ativa a correção de comandos do zsh
- **`uninstall.sh --full`**: remove Oh My Zsh, backups `.zshrc.zest-bak-*` e cache `.zcompdump-*` — sai sem deixar rastro
- `SECURITY.md` com política de divulgação responsável

### Segurança
- **Zero `curl | sh`**: Oh My Zsh via `git clone`; zoxide/atuin/mise via binários de release
- **Checksum SHA-256** conferido via API do GitHub + **validação ELF** antes de instalar binário
- **Plugins pinados por tag** (reprodutível)
- **HTTPS-only** em todas as APIs externas (wttr.in, ip-api, ifconfig.me)
- CI com `persist-credentials: false`; guards `--` em tar/rsync/wget/basename

### Docs
- README: seção **Desinstalação** (modo padrão e `--full`), destaque do comando `ajuda`, linha **Histórico do shell** e `spell` na seção de arquivos

## 0.1.7 — 2026-10-23

### Novo
- **CI no GitHub Actions** (`.github/workflows/ci.yml`): lint (`zsh -n`, `bash -n`, shellcheck) + smoke test + **instalação real** em Debian, Fedora, Arch e Alpine, com ciclo completo (instalar → reinstalar → `zest doctor` → desinstalar) e um job dedicado ao modo `--with-omz`
- README: GIF antes/depois do `topmem` (gerado do Zest real, sem edição)
- Apoio ao projeto: Lightning e Bitcoin (README, `.github/FUNDING.yml` e rodapé do `ajuda`)

### Corrigido
- `uninstall.sh` não depende mais de `python3` (usa `awk`) — agora funciona em Debian slim, Alpine e qualquer distro mínima
- `uninstall.sh` devolve o `.zshrc` **idêntico byte a byte** ao original (testado no CI)

## 0.1.6 — 2026-10-23

### Novo
- Comando `ajuda`: cheatsheet completo no terminal, com os comandos agrupados por tema

## 0.1.5 — 2026-10-23

### Corrigido
- URLs quebradas (404) de `fzf`, `duf` e `tldr` no `lib/install-tool.sh` — downloads agora são validados antes de instalar
- `zest doctor` passou a checar a sintaxe do `.zshrc` com o próprio zsh

## 0.1.4 — 2026-10-23

### Corrigido
- Auto-cura do `)` órfão que a v0.1.2 deixava no `.zshrc` (quebrava bash e zsh)
- Instalador oferece trocar o shell padrão para zsh (`chsh`), com instruções quando não há tty

## 0.1.3 — 2026-10-23

### Corrigido
- VMs sem locale UTF-8 (locale C) não quebram mais a instalação: usa `C.UTF-8` quando disponível
- Regex de `plugins=()` ancorado no início da linha — não casa mais o comentário de exemplo do Oh My Zsh

## 0.1.2 — 2026-10-23

### Novo
- **Instalação de dependências automática**: o instalador detecta zsh/git/curl/python3 faltando e instala sozinho via sudo (ou su/root em Debian sem sudo), suportando apt, dnf, pacman, zypper e apk
- `lib/install-tool.sh` funciona também só com `wget` (sem curl)
- README: caminho de instalação em máquina zerada via `wget` (tarball do GitHub)

### Corrigido
- O comando `zest` agora é **copiado** para `~/.local/bin` (antes era symlink e quebrava se a pasta do clone fosse apagada)
- README: seção "Problemas comuns (VM / máquina nova)" — incluindo o aviso de que `tests/smoke.sh` é teste de desenvolvedor, não etapa de instalação

## 0.1.1 — 2026-10-22

### Novo
- `--with-omz`: instala o Oh My Zsh automaticamente (unattended, sem root, sem trocar o shell do usuário) + plugins + lista `plugins=()`
- Modo **standalone**: sem Oh My Zsh, os plugins são clonados em `~/.config/zest/plugins` e carregados pelo novo módulo `10-plugins` — funciona com zsh puro, zinit, antidote ou qualquer framework
- Seção de créditos no README (Oh My Zsh, zsh-users, hlissner e todos os autores das ferramentas)

### Corrigido
- O instalador do Oh My Zsh herdava a variável `ZSH` do shell do usuário e tentava instalar no lugar errado — agora o destino é fixado em `~/.oh-my-zsh`
- Ordem de instalação: o Oh My Zsh agora é instalado ANTES do bloco do Zest entrar no `.zshrc`, garantindo o template com `plugins=()`

## 0.1.0 — 2026-10-22

Primeira versão, extraída de um `.zshrc` real que sobreviveu a meses de uso e correção de bugs.

### Módulos (13)
- `00-path` `05-safety` (NO_CLOBBER com `>>!` documentado, cache de completion)
- `20-tools` (atuin, mise, zoxide, direnv, delta, fzf, thefuck — todos com guardas)
- `21-keys` (setas ↑/↓ com busca por substring; só ativa com o plugin presente)
- `30-aliases` `41-daily` `43-git` `45-devops` `46-system` `47-projects` `48-text` `49-utils`
- `99-welcome` (silenciável com `ZEST_QUIET=1`)

### Infra
- `install.sh` — sem root, aditivo (bloco marcado `>>> zest >>>`), idempotente, backup do `.zshrc`
- `uninstall.sh` — remoção limpa, mantém ferramentas
- `bin/zest` — CLI: `doctor`, `update`, `add`
- `lib/install-tool.sh` — 16 ferramentas via GitHub releases, arquitetura detectada
- `tests/smoke.sh` — sintaxe + funções essenciais

### Bugs da vida já embutidos como lições
- alias com argumento não existe → funções
- `gpr` colide com o plugin git do Oh My Zsh → resolução com `unalias` documentada
- `done` é palavra reservada do zsh → `tododone`
- `noclobber` bloqueia `>>` em arquivo novo → funções usam `>>!`
- alias que chama a si mesmo → prefixo `command`
- npm global em `/usr/local` → sudo automático quando o prefixo não é gravável
