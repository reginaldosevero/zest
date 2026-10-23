# Changelog

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
