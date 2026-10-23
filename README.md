# 🌶️ Zest — o tempero do seu terminal

**Zsh** produtivo, legível para humanos e instalável em **qualquer distro Linux** — sem precisar de root.

> EN: Zest turns any Linux terminal into a productive, human-friendly shell. No root required. [Install ↓](#-instalação)

## Por quê?

O terminal Linux padrão é cru e as mensagens de erro parecem latim. O Zest acrescenta o **tempero**: aliasing inteligente, funções que falam português, barras gráficas, e ferramentas modernas — **sem remover nada** do que você já tem.

| Antes | Com Zest |
|---|---|
| `ps aux` ilegível | `topmem` → `firefox-esr 3,4 GB █████████░░░ 45%` |
| `df -h` com colunas crípticas | `df` → barras coloridas (duf) |
| `fatal: not a git repository` | `❌ Esta pasta não é um projeto git — dicas do que fazer` |
| 12 gerenciadores de pacote um por um | `updateall` → atualiza tudo, pula o que não existe |
| Anotações em post-its | `note` → nota rápida no terminal, `notes` numeradas, `noterm 3` |

## ✨ Princípios

1. **Zero root por padrão** — ferramentas vão para `~/.local/bin`
2. **Aditivo, nunca destrutivo** — o `.zshrc` recebe só um bloco marcado; backup automático
3. **Idempotente** — rodar o instalador 2x dá o mesmo resultado
4. **Tudo opcional** — sem fzf? Sem Oh My Zsh? Os módulos pulam o que não existir
5. **Reversível** — `uninstall.sh` sai limpo

## 📦 Instalação

Escolha o seu sabor — os módulos do Zest funcionam **com ou sem framework**:

| Você tem/quer | Comando |
|---|---|
| Zest puro (zsh puro, sem plugins extra) | `./install.sh` |
| Zest + plugins standalone (sem Oh My Zsh) | `./install.sh --with-plugins` |
| Zest + Oh My Zsh + plugins (instala o omz se faltar) | `./install.sh --with-omz` |
| Já usa zinit, antidote ou outro framework? | `./install.sh --with-plugins` — os plugins são scripts soltos, carregam em qualquer um |

```bash
git clone https://github.com/reginaldosevero/zest ~/projetos/zest
cd ~/projetos/zest
./install.sh --with-omz   # ou o sabor que preferir da tabela acima
```

Depois:

```bash
source ~/.zshrc
zest doctor                 # diagnostica o ambiente
zest add fzf bat eza ripgrep fd delta lazygit duf jq yq direnv tldr zoxide atuin mise
```

## 🧰 Comandos que o Zest traz

**Diagnóstico:** `sysinfo` · `topmem` · `topcpu` · `df` · `portcheck host porta` · `ipinfo`

**Produtividade:** `note` / `notes` / `noterm N` / `noteclean` · `todo` / `todos` / `tododone` · `calc 2+2` · `timer 25` · `worldtime` · `weather` · `news` (em português!)

**Git:** `git status` com mensagem amigável fora de repositórios · `glog` · `gpull` · `gstash "msg"` · `gclean_branches` · `lazygit`

**Arquivos:** `z` (cd inteligente) · `ll` · `lt` · `bat` · `fd` · `rg` · `extract arquivo.zip` · `syncdir origem destino` · `backup_dir pasta`

**Manutenção:** `updateall` (12 gerenciadores: apt, omz, mise, uv, pipx, pip, flatpak, snap, npm, rustup, opencode, tldr) · `sysclean` · `fuck` (corrige typos)

**Projetos em segundos:** `pyproject minha-api` · `nodeproject meu-site` · `goproject` · `rustproject`

## 🗂️ Estrutura

```
zest/
├── install.sh · uninstall.sh    # entram e saem limpos
├── bin/zest                     # CLI: doctor · update · add
├── modules/*.zsh                # um módulo por tema, todos com guardas
│   ├── 00-path · 05-safety · 20-tools · 21-keys
│   ├── 30-aliases · 41-daily · 43-git · 45-devops
│   └── 46-system · 47-projects · 48-text · 49-utils · 99-welcome
├── lib/install-tool.sh          # baixa binários certos por distro/arquitetura
└── tests/smoke.sh               # CI-ready
```

## 🗺️ Roadmap

- [x] **v0.1** — módulos funcionais + install/uninstall + doctor + smoke test
- [ ] **v0.2** — detecção de distro no install-tool (apt/dnf/pacman antes de binário)
- [ ] **v1.0** — i18n (pt_BR/en) · CI em Debian/Fedora/Arch/Alpine · curl | bash

## 📄 Licença

MIT — veja [LICENSE](LICENSE).

## 🙏 Créditos

O Zest não reinventa a roda — ele é o maestro de uma orquestra de projetos brilhantes:

- **[Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)** (MIT) — de Robby Russell e da comunidade. Inspiração direta dos aliases de git do Zest e do ecossistema de plugins. Opcional: o Zest funciona com ele ou sem ele.
- **Plugins zsh** (baixados pelo instalador, cada um com sua licença):
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) · [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) · [zsh-completions](https://github.com/zsh-users/zsh-completions) · [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) — time **zsh-users**
  - [zsh-autopair](https://github.com/hlissner/zsh-autopair) — hlissner
- **Ferramentas CLI** que o `zest add` baixa (apenas automatiza o download; cada uma mantém sua licença):
  - fzf (junegunn) · ripgrep (BurntSushi) · fd e bat (sharkdp) · eza (eza-community) · delta (dandavison) · lazygit (jesseduffield) · duf (muesli) · jq (jqlang) · yq (mikefarah) · direnv (direnv) · tealdeer (tealdeer-rs) · zoxide (ajeetdsouza) · atuin (ellie) · mise (jdx) · thefuck (nvbn)

Muito obrigado a todas essas pessoas. 🌶️
