# 🌶️ Zest — o tempero do seu terminal

![release](https://img.shields.io/badge/release-v0.3.2-8A2BE2) ![CI](https://github.com/reginaldosevero/zest/actions/workflows/ci.yml/badge.svg) ![licença](https://img.shields.io/github/license/reginaldosevero/zest) ![plataforma](https://img.shields.io/badge/plataforma-qualquer_Linux-success) ![shell](https://img.shields.io/badge/shell-zsh-red) ![root](https://img.shields.io/badge/root-n%C3%A3o_necess%C3%A1rio-brightgreen) ![idioma](https://img.shields.io/badge/docs-Portugu%C3%AAs-blue)

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

![topmem: ps aux cru vs. topmem do Zest](docs/topmem-antes-depois.gif)

*`topmem`: o mesmo `ps aux` acima, agrupado por programa e com barras — gerado direto do Zest, sem edição.*

## ✨ Princípios

1. **Zero root por padrão** — ferramentas vão para `~/.local/bin`
2. **Aditivo, nunca destrutivo** — o `.zshrc` recebe só um bloco marcado; backup automático
3. **Idempotente** — rodar o instalador 2x dá o mesmo resultado
4. **Tudo opcional** — sem fzf? Sem Oh My Zsh? Os módulos pulam o que não existir
5. **Reversível** — `uninstall.sh` sai limpo

## 📦 Instalação

**Você não precisa instalar dependências manualmente** — o instalador detecta o que falta (zsh, git, curl, python3) e instala sozinho, pedindo a senha do `sudo` (ou do `root` em Debian recém-instalado). Funciona com apt, dnf, pacman, zypper e apk.

### Copie e cole: funciona até numa máquina zerada

Máquina nova e container costumam vir **sem `git` e sem `curl`** — então não dá para começar por `git clone`. Este bloco resolve isso primeiro, em qualquer distro, e instala o Zest em seguida. Cole tudo de uma vez:

```bash
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
  apt-get update -qq && apt-get install -y -qq curl   # Debian/Ubuntu
  dnf install -y -q curl                              # Fedora
  pacman -Sy --noconfirm curl                         # Arch
  zypper --non-interactive install curl               # openSUSE
  apk add curl                                        # Alpine
} 2>/dev/null
{ curl -fsSL https://github.com/reginaldosevero/zest/archive/refs/heads/master.tar.gz \
  || wget -qO- https://github.com/reginaldosevero/zest/archive/refs/heads/master.tar.gz; } | tar xz
cd zest-master && ./install.sh
```

> Precisa rodar como quem pode instalar pacotes: `sudo -i` antes, num container já root não muda nada.
> As linhas de distro que não existirem na sua máquina são ignoradas — só a sua roda.

---

#### 🐳 Exemplo direto: **Debian/Ubuntu container limpo (root, sem nada)**

```bash
# Você está root no container, sem git, sem curl, sem sudo
apt-get update -qq && apt-get install -y -qq curl
curl -fsSL https://github.com/reginaldosevero/zest/archive/refs/heads/master.tar.gz | tar xz
cd zest-master && ./install.sh --with-omz
```

> **`--with-omz`** já instala o Oh My Zsh + plugins (autosuggestions, syntax-highlighting, etc.) junto. Sem isso, o Zest roda liso sem Oh My Zsh.
> Se quiser só o Zest (sem Oh My Zsh), tire o `--with-omz`.

---

#### 📦 Exemplo: **Debian/Ubuntu VM com usuário comum (tem sudo)**

```bash
sudo apt-get update && sudo apt-get install -y curl
curl -fsSL https://github.com/reginaldosevero/zest/archive/refs/heads/master.tar.gz | tar xz
cd zest-master && ./install.sh --with-omz
```

### Se você já tem git

```bash
git clone https://github.com/reginaldosevero/zest ~/projetos/zest
cd ~/projetos/zest && ./install.sh
```

### Sem linha de comando nenhuma

Baixe o ZIP pelo navegador em
[github.com/reginaldosevero/zest](https://github.com/reginaldosevero/zest) → botão **Code** → **Download ZIP**,
descompacte e rode `./install.sh` de dentro da pasta (ou `bash install.sh`, se o `+x` se perdeu no download).

### O que um único `./install.sh` entrega

Numa máquina zerada:

- os módulos do Zest
- as **17 ferramentas** (fzf, rg, fd, bat, eza, delta, zoxide, jq, yq, duf, lazygit, direnv, tldr, atuin, mise, uv, thefuck), baixadas em `~/.local/bin` — sem root
- o **prompt** (pergunta qual estilo na primeira execução; default: `zest`, que é o visual `╭─usuário ~/dir ❯` com status do git)
- os **plugins** se você quiser Oh My Zsh

Na primeira execução, o instalador pergunta qual prompt você quer (1-4, default 1). Só em terminal interativo: em instalações desatendidas ou em CI, o default é `zest`.

**Shell padrão:** se o login ainda for bash (ou outro), o Zest nunca carrega em um terminal novo — e a instalação pergunta se troca o shell para `zsh` (`chsh`). Em container sem `sudo`/tty, pergunta silenciosa e mostra a linha pronta. Comparação por inode (`-ef`): em distro com usrmerge, `/bin/zsh` e `/usr/bin/zsh` são o mesmo arquivo, então quem já usava zsh não era forçado a trocar.

### ⚠️ `zest add Oh My Zsh` não existe — e por quê

O `zest add` só baixa **ferramentas CLI** (fzf, rg, bat, eza, atuin, etc.). Oh My Zsh é um **framework de shell**, não uma ferramenta — então ele não está na lista de `zest add`. Tentar `zest add Oh My Zsh` divide o nome em palavras e diz "Ferramenta desconhecida: Oh / My / Zsh".

Para ter o Oh My Zsh, use uma das opções abaixo.

### 🧩 Oh My Zsh (opcional)

O Zest funciona **sem** Oh My Zsh — os módulos são código zsh próprio. Mas se você quer os themes, aliases e integrações do Omz, tem três caminhos:

**1) Na instalação (recomendado para quem está começando do zero)**

```bash
./install.sh --with-omz
```

O instalador detecta se o Omz já existe; se não, instala sozinho (precisa de `git`; em container root, `apt install git -y` é o jeito — sem `sudo`). Se o `git` não estiver disponível, o Omz é pulado e o Zest continua normal.

**2) Depois que o Zest já está instalado**

```bash
cd ~/projetos/zest
./install.sh --with-omz
```

Mesmo rodando de novo, o instalador é idempotente: o que já existe é pulado, e o Omz é instalado se faltar.

**3) Manual (sem o Zest gerenciar)**

```bash
apt install git -y          # root no container: sem sudo
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

> O instalador oficial do Omz **precisa de `git`**. Sem ele, a instalação falha com "git is not installed". Em container enxuto, instale o `git` primeiro (`apt install git -y`) e rode de novo.

**Plugins:** com `--with-plugins` o Zest também baixa os plugins soltos (zsh-autosuggestions, zsh-syntax-highlighting, etc.) que funcionam em qualquer framework — incluindo o Omz, zinit, antidote ou só o próprio Zest.

### Sabores

| Você tem/quer | Comando |
|---|---|
| Zest completo (padrão) | `./install.sh` |
| Zest + Oh My Zsh + plugins (instala o omz se faltar) | `./install.sh --with-omz` |
| Zest + plugins, sem Oh My Zsh | `./install.sh --with-plugins` |
| Já usa zinit, antidote ou outro framework? | `./install.sh --with-plugins` — os plugins são scripts soltos, carregam em qualquer um |
| CI ou teste rápido (pula as 17 ferramentas) | `./install.sh --no-tools` |

Depois:

```bash
source ~/.zshrc
zest doctor                 # diagnostica o ambiente
```

O `zest add` baixa **binários de release** para `~/.local/bin` — por isso não pede root. Se você preferir o pacote oficial da sua distro (atualiza junto com o sistema), peça o caminho nativo:

```bash
zest add --prefer-pm jq tealdeer    # instala pelo apt/dnf/pacman/zypper/apk (pede sudo)
```

O pacote só é usado quando ele realmente instala o binário com o nome que o Zest espera. No Debian/Ubuntu, por exemplo, `bat` instala `batcat` e `fd-find` instala `fdfind` — nesses casos o Zest vai direto para o binário de release, em vez de deixar um comando com nome errado parado no sistema.

## 🧰 Comandos que o Zest traz

> **Não sabe por onde começar?** Digite `ajuda` em qualquer terminal. Sai uma colinha com tudo que o Zest oferece, organizada por categoria. Aceita filtro: `ajuda git`, `ajuda histórico`, `ajuda nota`.

**Diagnóstico:** `sysinfo` · `topmem` · `topcpu` · `df` · `portcheck host porta` · `ipinfo`

**CLI do Zest:** `zest doctor` · `zest update` · `zest add <ferramenta>` · `zest prompt [zest|compact|plain|off]` — mostra ou troca o estilo do prompt sem abrir arquivo algum.

**Produtividade:** `note` / `notes` / `noterm N` / `noteclean` · `todo` / `todos` / `tododone` · `calc 2+2` · `timer 25` · `worldtime` · `weather` · `news` (em português!)

**Git:** `git status` com mensagem amigável fora de repositórios · `glog` · `gpull` · `gstash "msg"` · `gclean_branches` · `lazygit`

**Arquivos:** `z` (cd inteligente) · `ll` · `lt` · `bat` · `fd` · `rg` · `extract arquivo.zip` · `syncdir origem destino` · `backup_dir pasta`

**Manutenção:** `updateall` (12 gerenciadores: o da sua distro, omz, mise, uv, pipx, pip, flatpak, snap, npm, rustup, opencode, tldr) · `sysclean` · `fuck` (corrige typos)

**Projetos em segundos:** `pyproject minha-api` · `nodeproject meu-site` · `goproject` · `rustproject`

**Histórico do shell:** `histnum` (lista numerada) · `histsed N` (apaga uma linha) · `histdel 'senha'` (apaga todas com o padrão) · `histclear` (apaga tudo) · `histsearch` · `histcount` · `histclean` (remove duplicatas)

**Novo ✨ Ortografia:** `spell` (novo!) · `correct` · `spell arquivo` · `spell -` · `spell -x` — veja a seção **spell — corretor ortográfico** logo abaixo

**Funções:** `code` (VS Code, cai em code-insiders) · `zed` (Zed editor) · `procs` (processos, cai em `ps aux`) · `geoip IP` (onde está um IP, via ip-api) · `gfiles [branch]` (arquivos alterados no diff) · `histsize N` (corta o histórico para as últimas N linhas) · `stopwatch` (cronômetro, Enter para parar) · `date2ts DATA` / `ts2date TS` (conversão data ↔ timestamp Unix) · `urldecode TEXTO` (decodifica URL-encoded) · `dcp origem:destino` / `dsh container` / `drmi [imagem]` / `dlogsall` / `dbuildpush tag` (Docker: cp, exec, rmi, logs de todos, build+push)

## ✅ spell — corretor ortográfico (novo!)

Função **nova do Zest**: verifica ortografia de qualquer texto em português com o [aspell](http://aspell.net) (dicionário `pt_BR` ativado automaticamente quando instalado).

```bash
spell readme.txt      # verifica um arquivo: lista cada erro com sugestões
spell -               # verifica o que você digita (Ctrl+D no fim) — ou use pipe:
echo "este texo tem exeplario" | spell -
spell -x              # verifica o texto que você COPIOU (Ctrl+C em qualquer lugar)
spell -i readme.txt   # interativo: corrige palavra por palavra
```

Saída real:

```
❌ texo
   → teixo, texto, teco, taxo, teio, mexo, nexo, sexo

📝 1 palavra(s) com problema em readme.txt
   para corrigir uma a uma: spell -i readme.txt
```

> **`correct`** — comando extra que ativa a correção de **comandos** nativa do zsh:
> você digita `git stautos` e o zsh pergunta se era `git status`.

### ⌨️ Corrigir enquanto digita: **Alt+S**

Escreveu uma palavra errada **na linha de comando**? Mova o cursor para ela (ou deixe logo depois) e aperte **Alt+S**: o Zest consulta o aspell e troca pela correção na hora, sem sair do terminal.

```
$ echo este texo para voce        ← cursor em qualquer lugar de "voce"
   (Alt+S)
$ echo este texo para você        ✔ corrigido: voce → você
   (Alt+S de novo, agora em "texo")
$ echo este texto para você       ✔ corrigido: texo → texto
```

Funciona com acentos (`recepcao` → `recepção`) e respeita a palavra correta sem mexer nela.

## 🗂️ Estrutura

```
zest/
├── install.sh · uninstall.sh    # entram e saem limpos
├── bin/zest                     # CLI: doctor · update · add
├── modules/*.zsh                # um módulo por tema, todos com guardas
│   ├── 00-path · 05-safety · 06-pm · 10-plugins · 20-tools
│   ├── 21-keys · 30-aliases · 41-daily · 43-git · 45-devops
│   ├── 46-system · 47-projects · 48-text · 49-utils · 50-history
│   └── 98-ajuda · 99-welcome
├── lib/distro.sh                # detecta apt/dnf/pacman/zypper/apk (zero hardcode)
├── lib/install-tool.sh          # binário por distro/arquitetura, com checksum
└── tests/smoke.sh               # CI-ready
```

## 🧹 Desinstalação

O Zest sai limpo: basta rodar `uninstall.sh` no diretório do projeto.

**Modo padrão** (seguro — só remove o Zest, mantém seu setup):

```bash
git clone https://github.com/reginaldosevero/zest
cd zest
bash uninstall.sh
```

Remove:
- bloco `>>> zest >>>` do `.zshrc`
- módulos em `~/.config/zest/`
- comando `~/.local/bin/zest`

Mantém (intencional):
- ferramentas CLI instaladas via `zest add` (bat, fzf, rg…)
- backups `.zshrc.zest-bak-*`
- Oh My Zsh (se estiver instalado)

**Modo completo** (remove TUDO que o Zest criou):

```bash
bash uninstall.sh --full
```

Além do modo padrão, remove também:
- `~/.oh-my-zsh/` (instalado pelo Zest)
- backups `.zshrc.zest-bak-*`
- cache de completion `.zcompdump-*`

Em ambos os casos, as ferramentas CLI em `~/.local/bin` ficam — se quiser apagá-las também:

```bash
rm -f ~/.local/bin/{fzf,zoxide,atuin,mise,jq,yq,direnv,eza,rg,fd,bat,delta,lazygit,duf,tldr}
```

---

## 🗺️ Roadmap

- [x] **v0.1** — módulos funcionais + install/uninstall + doctor + smoke test
- [x] **CI em Debian/Fedora/Arch/Alpine** — instalar → reinstalar → doctor → desinstalar (v0.1.7)
- [x] **v0.2** — detecção de distro: `sysclean` e `updateall` seguem o gerenciador da máquina, e `zest add --prefer-pm` instala pelo pacote nativo
- [ ] **v1.0** — i18n (pt_BR/en)

## 📄 Licença

MIT — veja [LICENSE](LICENSE).

## 💸 Apoie o Zest

O Zest é gratuito e sempre será. Se ele te ajudou, uma doação espontânea é sempre bem-vinda:

**⚡ Lightning Network** (instantâneo, taxas mínimas):
```
nados@speed.app
```

**₿ Bitcoin (on-chain)**:
```
bc1qyxsu8mhgujqau8e87lthgxg08eq0qw0426du5z
```

> EN: Zest is free forever. If it helped you, Bitcoin donations are welcome — Lightning or on-chain (addresses above). Obrigado / Thank you! 🌶️

## 🆘 Problemas comuns (VM / máquina nova)

| Sintoma | Causa | Solução |
|---|---|---|
| `command not found: git` ao clonar | git não instalado | instale pelo gerenciador da distro (`apt install`, `dnf install`, `pacman -S`, `zypper install`, `apk add`) |
| O instalador diz `❌ Pré-requisitos faltando: zsh…` | zsh não instalado | o próprio instalador resolve — ele detecta o gerenciador e pede a senha |
| `zest add` falha em tudo | falta `curl`/`wget` | instale o `curl` pelo gerenciador da distro |
| `./install.sh: Permission denied` | baixou o ZIP (perde o +x) | `bash install.sh --with-omz` |
| `✗ sintaxe` no `tests/smoke.sh` | **não rode o smoke como usuário** — é teste de desenvolvimento e exige zsh instalado | apenas rode `./install.sh` |

O instalador diagnostica tudo sozinho: se algo faltar, ele diz **o quê** e **o comando exato** (com `sudo` ou `su`) para resolver.

## 🙏 Créditos

O Zest não reinventa a roda — ele é o maestro de uma orquestra de projetos brilhantes:

- **[Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)** (MIT) — de Robby Russell e da comunidade. Inspiração direta dos aliases de git do Zest e do ecossistema de plugins. Opcional: o Zest funciona com ele ou sem ele.
- **Plugins zsh** (baixados pelo instalador, cada um com sua licença):
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) · [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) · [zsh-completions](https://github.com/zsh-users/zsh-completions) · [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) — time **zsh-users**
  - [zsh-autopair](https://github.com/hlissner/zsh-autopair) — hlissner
- **Ferramentas CLI** que o `zest add` baixa (apenas automatiza o download; cada uma mantém sua licença):
  - fzf (junegunn) · ripgrep (BurntSushi) · fd e bat (sharkdp) · eza (eza-community) · delta (dandavison) · lazygit (jesseduffield) · duf (muesli) · jq (jqlang) · yq (mikefarah) · direnv (direnv) · tealdeer (tealdeer-rs) · zoxide (ajeetdsouza) · atuin (ellie) · mise (jdx) · thefuck (nvbn)

Muito obrigado a todas essas pessoas. 🌶️
