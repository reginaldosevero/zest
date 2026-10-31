# Changelog

## 0.3.2 — 2026-10-31

### Correção
- **Container limpo sem git, sem tty, sem sudo — o caso real do usuário.**
  Antes, instalar em uma VM/container zerada rodando apenas `install.sh`
  (sem `lib/`, sem `git`, sem terminal de controle) dava erro em três
  pontos e saía com código não-zero. Agora funciona de ponta a ponta:
  - **`git` não é mais obrigatório.** O download do repo cai para o tarball
    via `curl`/`wget`, e cada dependência só entra na lista quando o fluxo
    real a usa: `git` é cobrado apenas com `--with-omz`/`--with-plugins`,
    e o baixador pede `curl` *ou* `wget` (não os dois).
  - **`/dev/tty` não vaza mais na tela.** `ask()` e `has_tty()` calam o
    stderr *antes* de abrir o device (`2>/dev/null < /dev/tty` — as
    redireções são da esquerda para a direita). Em container sem terminal
    de controle o `[[ -c /dev/tty ]]` dizia "existe" e o `read` falhava
    com "No such device or address" no meio da instalação.
  - **`su` como fallback do `sudo`** em container root sem `sudo`.
  - **Wrappers autossuficientes** (`pm_run`/`pm_detect`/`pm_install`/
    `pm_update`): o fallback do checkout sem `lib/distro.sh` não mais
    quebra por chamar uma função que só existia dentro do `if`.
- **`ZEST_ORIGIN` (default: o repositório oficial).** Quem mantém um fork
  aponta para o próprio: `ZEST_ORIGIN=https://github.com/eu/zest ./install.sh`.
  O nome é deliberadamente `ZEST_ORIGIN` — `ZEST_REPO` já é usado pelo
  `bin/zest` como o *direatório* do repo, e reutilizá-lo quebraria o CLI.
- **Shell padrão comparado por `-ef` (device+inode), não por string.**
  Em distro com usrmerge, `/bin/zsh` e `/usr/bin/zsh` são o mesmo arquivo
  e o `passwd` pode ter gravado qualquer um dos dois: o instalador
  dizia "seu shell não é zsh" numa conta que já usava zsh, e tentava
  `chsh` à toa.
- **`lib/install-helpers.sh` (novo).** `check_elf`/`unpack_bin`/
  `finish_bin` vivem em um único lugar: `install-tool.sh` e `tests/smoke.sh`
  os carregam. Cópias divergem — ver CHANGELOG 0.2.0, quando um `zest_pkg`
  antigo sobreviveu e passou por cima.
- **`unpack_bin` extrai cada tarball em `mktemp -d "$T/x-XXXXXX"`** —
  instalar mais de uma ferramenta na mesma execução já não contaminava a
  busca do próximo (o `find` podia devolver o binário de um tarball
  anterior).
- **`smoke` #14/#15/#16.** #14 usa as funções *reais* (raiz, subpasta,
  recusa sem-ELF); #15 exige `-ef` em `install.sh`; #16 proíbe `[[ -c
  /dev/tty ]]` e `< /dev/tty` sem o erro calado.

### Melhorias
- **`zest add` não exige `git`/`curl` para baixar o Zest.** O `zest_src_resolve`
  tenta `git clone` e cai para o tarball do branch padrão via `curl` ou
  `wget` — e a mensagem de falha diz o que falta (git, *ou* curl/wget + gzip).

---

## 0.3.1 — 2026-10-31

### Correção
- **`zest doctor` testa o binário real** (segunda coluna de `tools.list`).
  Antes, `command -v ripgrep` falhava porque o binário é `rg` — o doctor
  dizia "zest add ripgrep" mesmo com o rg em `~/.local/bin`. Agora
  testa `$_b`, e o smoke tem uma guarda nova que procura "zest add rg"
  (que não é um comando do Zest).
- **`install.sh` troca o shell padrão para zsh** em máquina nova. Antes,
  o instalador não tocava no login shell: em um terminal novo o bash
  abria e o Zest nunca carregava. Agora pergunta com `ask()` (funciona
  em `curl … | bash`), tenta o chsh em ordem de silêncio (já autorizado
  → PAM de terminal → sudo sem senha → sudo com senha) e, se nenhuma
  der certo, mostra a linha pronta `sudo chsh -s <zsh> <usuário>`.
- **`install.sh` não lê do stdin.** Em `curl … | bash` o stdin é o
  próprio script: um `read` cru engolia o resto e nada era perguntado
  (foi o que calou a escolha do prompt). Agora a pergunta vai para
  `/dev/tty` (ou devolve 1 sem terminal, default = `zest`).
- **`install.sh` cai com mensagem clara em `curl … | bash`.** Sem
  `BASH_SOURCE` o script não encontra `lib/` e estourava um erro
  confuso; agora diz "clone o repo e rode `./install.sh`".
- **`zest prompt`** — mostra ou troca o estilo (zest/compact/plain/off)
  sem abrir o arquivo na mão. Com outro framework (Oh My Zsh/starship)
  avisa que não sobrescreve.
- **`doctor` cobra o shell padrão.** Em máquina nova o login costuma
  ser bash, e o diagnóstico dizia "tudo saudável" com o Zest morto em
  todo terminal novo.

### Interno
- `tests/smoke.sh` ganhou guardas: pergunta via `/dev/tty`, doctor checa
  shell padrão, `zest prompt` aceita os 4 estilos e recusa os outros,
  segunda coluna de `tools.list` é nome de binário limpo e o install.sh
  instala a lista de `tools.list` (não nomes soltos).
- `uninstall.sh` remove também o bloco do Zest do `.bashrc` (quando o
  login ainda era bash), devolvendo o arquivo byte a byte.

### Novo
- **Instalação padrão agora é completa.** Num `./install.sh` de uma máquina
  zerada saem módulos, 17 ferramentas e o prompt — sem passos manuais.
  Antes, `zest add`, plugins e tema eram opções que quase ninguém usava.
- **`lib/tools.list`** — fonte única das 17 ferramentas. Antes a lista
  estava hardcodeada em três lugares (bin/zest, install.sh e a ajuda);
  uma adição precisava de três edições e o smoke não garantia que
  estivessem iguais. Agora `install.sh`, `install-tool.sh` (available())
  e `zest doctor` leem o mesmo arquivo.
- **Módulo 22-prompt** — prompt sem framework. Estilo `zest`
  (`╭─usuário ~/dir ❯` com branch e ●/✚ do vcs_info), `compact` e `plain`.
  `ZEST_PROMPT=off` desliga; sem variável, autodetecta: se o PS1 já não
  é o default do zsh cru, assume que outro framework (Oh My Zsh,
  starship, powerlevel10k) já chegou e não mexe.
- **`install.sh` pergunta o estilo do prompt na primeira execução**
  (1/2/3/4, default 1). Só em terminal interativo: em CI e em
  instalações desatendidas o default é `zest`.
- **`zest add` com suporte a musl/Alpine.** fd, bat, eza e delta tinham
  só a build gnu no `install-tool.sh`, então em Alpine (musl) o download
  falhava silenciosamente. `pick_asset()` agora percorre
  `LIBC_ORDER` (musl antes de gnu, ou o inverso) e pega a primeira build
  que o upstream publica. Delta não tem musl para arm64 — a lista
  termina em gnu, sem isso o instalador morria na primeira tentativa.
- **`zest add thefuck` baixa o `uv` primeiro**, se não estiver em PATH nem
  em `~/.local/bin`. O thefuck é instalação de Python e depende do uv.

### Corrigido
- **`zest doctor` lia a lista de ferramentas de um `TOOLS=` hardcodado**
  em `bin/zest` que não tinha o `uv` — e o `uv` é do `thefuck` em
  `install-tool.sh`. Agora lê `lib/tools.list` (com fallback para o
  repositório, no caso de `ZEST_HOME` apontando para outro lugar).
- **`zest doctor` interpretava os comentários do `tools.list` como
  ferramentas** (ex.: `# zest :: lista de ferramentas — FONTE ÚNICA` vira
  `zest add #`). Os três leitores ignoram linhas em branco e `#`.
- **`install.sh` mandava a lista de ferramentas como um único argumento
  com espaço**, e o `install-tool.sh` viu só o primeiro nome. Agora
  passa os nomes separados por espaço (word splitting intencional).
- **CI: os 4 jobs de instalação (Debian/Fedora/Arch/Alpine) passam a
  rodar `install.sh --no-tools`** — instalar as 17 ferramentas em cada
  um deles seria ~240 MB de download e 4-6 minutos a mais, sem acrescentar
  cobertura (as receitas já passam pelo smoke local).
- **`uninstall.sh` não mencionava o prompt** na saída. Agora diz que o
  arquivo de escolha em `~/.config/zest/prompt` é removido junto com o
  restante, e que as ferramentas em `~/.local/bin` ficam de propósito.

### Detalhes
- `install-tool.sh`: `get()` usa `zest_pm_hint` para a dica de "instale
  curl" em vez de hardcodear `sudo apt install -y curl`.
- O prompt é salvo em `$ZEST_HOME/prompt` (zest|compact|plain|off), e o
  módulo 22 lê esse arquivo quando `ZEST_PROMPT` não está definido na
  linha de comando.
- Roadmap: v0.3 concluída. Próxima: v1.0 — i18n (pt_BR/en).

## 0.2.0 — 2026-10-30

### Novo
- **Detecção de distro de verdade** (`lib/distro.sh` + `modules/06-pm.zsh`): `sysclean`, `updateall` e as dicas de instalação descobrem se a máquina é apt, dnf, pacman, zypper ou apk. Acabou o `sudo apt` fixo dentro dos módulos.
- **`zest add --prefer-pm`**: instala pelo gerenciador da distro em vez do binário de release (atualiza junto com o sistema). Continua opt-in — o padrão segue sem pedir root.
- **`zest doctor` mostra o gerenciador detectado**, junto das ferramentas.

### Corrigido
- **`sysclean` quebrava fora do Debian/Ubuntu**: era `sudo apt autoremove && sudo apt autoclean` puro. Agora usa `autoremove` + limpeza de cache do gerenciador detectado, e pula `journalctl` onde não há systemd (Alpine/OpenRC).
- **`updateall` passo 1 era `sudo apt update` puro** — em Fedora/Arch/Alpine falhava. Passa a usar update + upgrade + autoremove do gerenciador da máquina.
- **`spell` dava dica de `sudo apt install` em qualquer distro** — a mensagem agora sai no formato do gerenciador certo (`dnf`, `pacman -S`, `zypper`, `apk add`).
- **`zest add` não instala pacote com nome de binário trocado**: no apt, `bat` instala `batcat` e `fd-find` instala `fdfind`. Instalar o pacote "quase certo" deixava um binário com nome errado e os aliases do Zest apontando para nada. Esses casos vão direto para o binário de release.
- **`yq` nunca vem do apt**: o `yq` do Debian é o wrapper Python do jq, não o yq Go usado por `json2yaml`/`yaml2json`.

### Detalhes
- Antes de pedir `sudo`, o instalador consulta o repositório (`apt-cache policy`, `dnf list`, `pacman -Si`, `zypper info`, `apk info`) para ver se o pacote existe — sem senha gasta em pacote inexistente.
- Nomes de pacote tratados por distro: `fd-find` (dnf), `git-delta` (apt/pacman), `tealdeer` (o pacote do `tldr`).
- `journalctl`, `snap` e `npm -g` passam por `_zest-sudo`, que cai em `su -c` quando não há sudo.
- **`sysclean` não morre mais em `~/.cache/thumbnails` vazio**: o glob estourava em `NOMATCH` no zsh quando a pasta não tinha arquivos.
- Smoke test ganhou três guardas: nenhum módulo chama gerenciador direto, nenhuma função interna é definida duas vezes, e o mapa de pacotes não devolve nome cujo binário seria outro.
- Roadmap: v0.2 concluída.

## 0.1.9 — 2026-10-27

### Segurança
- **`replace`**: busca e troca agora são LITERAL (não regex) — metacaracteres como `.`, `*`, `/`, `[` e `^` perdem o significado especial. Busca via `grep -rlF` e ambos os lados escapados para `sed`.
- **`tododone`**: localiza a linha exata com `grep -Fn` e edita só essa linha com `sed` delimitado por `|`. Tarefas com `/`, `[` ou `]` não quebram mais o sed e a tarefa não ficava marcada silenciosamente.
- **`weather`**: a cidade é URL-encoded (`jq -Rr @uri`) antes de `?format=3`, impedindo injeção de parâmetros de query por entrada do usuário. Adicionado `--max-time 8`.
- **`install.sh`**: clone do Oh My Zsh usa `--single-branch --branch master` e registra o commit SHA efetivamente instalado em `~/.oh-my-zsh/.zest-omz-pin` para auditoria/reprodutibilidade (upstream não publica tags/releases).

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
