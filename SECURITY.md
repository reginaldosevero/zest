# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | ✅                 |
| 0.2.x   | ✅                 |
| 0.1.9   | ✅                 |
| < 0.1.9 | ❌ (sem suporte)   |

> 0.3.2 (2026-10-31) é a versão atual. Correções de segurança do 0.1.9
> estão incluídas em 0.3.x e 0.2.x — veja o CHANGELOG.

## Reporting a Vulnerability

Levamos segurança a sério. Se você encontrar uma vulnerabilidade, reporte de forma responsável:

1. **Denúncia privada no GitHub** (canal principal): [Security advisory](https://github.com/reginaldosevero/zest/security/advisories/new) — abre uma conversa privada com o mantenedor, e nada é publicado até o fix sair
2. **Perfil no GitHub**: se o canal acima não funcionar, use "Report abuse" → "Report a security vulnerability" em [github.com/reginaldosevero](https://github.com/reginaldosevero)
3. **Lightning (se preferir)**: nados@speed.app

> Não abra issue pública descrevendo a vulnerabilidade. Assim o problema vira receita para exploração antes de existir correção.

### O que incluir na denúncia

- Descrição do problema
- Impacto esperado
- Passos para reproduzir (se possível)
- Sua preferência de contato para follow-up

### O que esperar

- **Acknowledgment**: resposta em até 48h úteis
- **Update**: atualizações a cada 7 dias enquanto trabalhamos no fix
- **Fix**: versão corrigida o mais breve possível (segregação de crédito opcional)
- **Disclosure**: publicação conjunta ou depois do fix (sua escolha)

## Security Practices

O Zest segue estes princípios:

- **Zero root por padrão** — tudo instalado em `~/.local/bin`
- **Installador aditivo** — nunca sobrescreve seu `.zshrc`, só acrescenta bloco marcado
- **Verificação de integridade** — checksums SHA-256 conferidos via GitHub API
- **Binários validados** — todo executável checa formato ELF antes de instalar
- **Sem `eval` de entrada** — os `eval` são só de inicialização de ferramentas (atuin, mise, zoxide)
- **Nenhuma credencial** codificada no repositório
- **Secret scanning** ativo via GitHub
- **HTTPS-only** em downloads e APIs externas

## Known Limitations (por design)

- `sudo` é usado apenas quando o usuário já tem privilégios de administrador (atualizações do sistema)
- `updateall` executa comandos do sistema — só em ambientes controlados pelo usuário
- Funções de rede (`weather`, `news`, `crypto`) consultam APIs públicas — confiança nos provedores externos

## Contact

Projeto mantido por [reginaldosevero](https://github.com/reginaldosevero) — Linux, terminal e open source 🌶️
