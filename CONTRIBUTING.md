# Contribuindo com o Zest 🌶️

Que bom que você quer contribuir. Este documento diz como fazer isso sem perder tempo — nem o seu, nem o de quem revisa.

## Antes de começar

O Zest tem cinco princípios que todo Pull Request precisa respeitar (ver [README](README.md#-princípios)):

1. **Zero root por padrão** — nada de exigir `sudo` num caminho que hoje não exige
2. **Aditivo, nunca destrutivo** — o `.zshrc` do usuário só recebe o bloco marcado `>>> zest >>>`
3. **Idempotente** — rodar o instalador duas vezes dá o mesmo resultado
4. **Tudo opcional** — sem `fzf`, sem Oh My Zsh, sem `jq`? Os módulos pulam o que não existir
5. **Reversível** — `uninstall.sh` tira tudo, inclusive byte a byte o que adicionou

Se a sua mudança quebra algum desses, abra uma *issue* antes de escrever código.

## Como rodar o projeto localmente

```bash
git clone https://github.com/reginaldosevero/zest
cd zest
bash tests/smoke.sh            # sintaxe + carregamento + CLI, roda em qualquer distro
```

Para testar a instalação sem mexer na sua máquina, use um container:

```bash
docker run --rm -it -v "$PWD":/zest debian:stable-slim
# dentro do container:
apt-get update && apt-get install -y git
cd /zest && bash install.sh --with-omz && zsh -c 'zest doctor'
```

Troque `debian:stable-slim` por `fedora:latest`, `archlinux:latest` ou `alpine:latest` para cobrir as outras distros do CI. O que o CI faz, você consegue fazer igual localmente.

## Estilo de código

Python não é o caso aqui — o projeto é shell puro:

- **Módulos zsh** vivem em `modules/`, um arquivo por tema, prefixo numérico define a ordem de carregamento (`00-path` antes de `46-system`, que usa as funções dele)
- **Bash** em `install.sh`, `uninstall.sh`, `bin/zest` e `lib/`
- 4 espaços de indentação
- `snake_case` para comandos expostos ao usuário, `_zest-` para função interna (não aparece na ajuda)
- Mensagens para o usuário em **português**; comentários explicam o *porquê*, não o *o quê*
- Nome de comando: se colidir com palavra reservada do zsh, escolha outro (`done` → `tododone`)

### Guarda obrigatória

Toda função que depende de ferramenta externa precisa degradar bem:

```zsh
# Certo — avisa e sai
json2yaml() { command -v yq >/dev/null 2>&1 && yq -P "$1" || echo "yq não instalado"; }

# Errado — quebra com "command not found"
json2yaml() { yq -P "$1"; }
```

E nada de hardcode de distro: `sudo apt ...` dentro de módulo está fora. Use as funções de detecção de `modules/06-pm.zsh` (`_zest-pm-detect`, `_zest-pm-hint`, …).

## Segurança

Instalar software é o coração do Zest, então estas regras são rígidas:

- **Nenhum `curl | sh`** — todo binário é baixado, verificado e só então movido
- **Checksum SHA-256** conferido contra a API do GitHub quando o upstream publica o digest
- **Validação de ELF** antes de mover qualquer binário para `~/.local/bin`
- **HTTPS-only**, com `--proto '=https'`
- Pacote da distro só entra quando o binário que ele instala tem **exatamente** o nome que o Zest espera (senão fica um comando órfão)
- Nunca commitar credencial, nem em teste, nem em exemplo

Encontrou uma vulnerabilidade? Veja [SECURITY.md](SECURITY.md) — não abra issue pública.

## Ciclo de contribuição

1. **Abra uma issue primeiro** para mudanças maiores de comportamento. Uma conversa de dez minutos evita um PR que não entra.
2. Branch a partir de `master` com nome descritivo: `fix/sysclean-fedora`, `feat/clipboard-history`.
3. Commit com resumo no imperativo e escopo quando ajudar: `fix(system): sysclean segue o gerenciador da distro`.
4. Rode `bash tests/smoke.sh` e adicione cobertura quando fizer sentido — o smoke é barato de estender.
5. Abra o PR contra `master`, apontando a issue, com escopo único: um problema por PR.
6. Se ainda está em andamento, comece o título com `WIP`.

Documente a mudança em `CHANGELOG.md` na versão em desenvolvimento, na seção que combina com ela (`Novo`, `Corrigido`, `Segurança`, `Docs`).

## Revisão

Quem revisa verifica, nesta ordem:

1. Algum princípio foi violado? (root, destrutivo, idempotência, guarda, reversibilidade)
2. Alguma distro do CI foi esquecida?
3. Tem `CHANGELOG.md`?
4. Destruiu a configuração de alguém sem avisar?

Bugs de digitação e formatação a gente corrige direto no review. Discussão de arquitetura fica em issue.

## Licença

Ao contribuir, você concorda que suas mudanças entrem sob a licença MIT do projeto.
