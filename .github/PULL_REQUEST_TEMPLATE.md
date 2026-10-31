## O que muda

Descreva a mudança em uma ou duas frases. Comece pelo problema, não pelo arquivo.

Closes #

## Tipo

- [ ] Correção
- [ ] Novo comando ou módulo
- [ ] Melhoria de documentação
- [ ] Mudança de comportamento (o usuário faz algo diferente depois disso)

## Como validei

Marque o que você realmente rodou — sem marcar o que não rodou.

- [ ] `bash tests/smoke.sh` passou
- [ ] Instalei do zero numa distro: `________`
- [ ] Testei reinstalar por cima da instalação anterior (idempotência)
- [ ] Testei `bash uninstall.sh` e o `.zshrc` voltou ao original
- [ ] Rodei `zest doctor` depois da mudança

Se a mudança toca em instalação, distro ou download de binário, conte qual container você usou:

```bash
docker run --rm -it -v "$PWD":/zest debian:stable-slim
```

## Princípios

O Zest tem cinco princípios (veja "Princípios" no README). Marque os que sua mudança afeta e explique como continua respeitando:

- [ ] Zero root por padrão — continua sem exigir `sudo` onde hoje não exige
- [ ] Aditivo — nada de sobrescrever o que é do usuário
- [ ] Idempotente — rodar o instalador 2x dá o mesmo resultado
- [ ] Tudo opcional — as guardas continuam cobrindo o que faltar
- [ ] Reversível — o `uninstall.sh` continua tirando o que o `install.sh` pôs

## Segurança

Responda sim ou não:

- Alguma linha nova baixa algo da rede? Em caso afirmativo, passa por checksum e validação de formato?
- Alguma linha nova usa `sudo`? Em caso afirmativo, em que caminho e por que é inevitável?
- Você colocou pacote de distro no `zest_pkg`? O binário que esse pacote instala tem exatamente o nome que o Zest espera?

## Checklist

- [ ] `CHANGELOG.md` atualizado na versão em desenvolvimento
- [ ] `README.md` e `ajuda` (módulo 98) atualizados se o comportamento visível mudou
- [ ] Nada de segredo, token ou caminho pessoal no diff
