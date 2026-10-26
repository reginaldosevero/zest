# zest :: ajuda — cheat sheet de todos os comandos (ajuda <termo> filtra)
ajuda() {
  local body
  body=$(cat <<'FIM'
🌶️  ZEST — comandos disponíveis (use: ajuda <termo> para filtrar)

SISTEMA
  sysinfo              resumo do PC: RAM, disco, CPU com barras coloridas
  topmem               quem mais usa memória (agrupado por programa)
  topcpu               quem mais usa CPU (agrupado por programa)
  df                   uso dos discos (bonito, via duf)
  diskusage_dir pasta  o que mais pesa dentro de uma pasta
  ipinfo               IP público + local + gateway + DNS
  portcheck host porta testa se uma porta está aberta
  portinfo porta       qual processo usa a porta
  worldtime            hora em 7 fusos (Brasil, EUA, Europa, Ásia...)
  temps                temperatura do sistema

PRODUTIVIDADE
  note                 salva nota digitando + Enter (note texto = direto)
  notes                lista as notas numeradas
  noterm N             apaga a nota número N
  noteclean            apaga TODAS as notas (pede confirmação)
  todo                 salva tarefa (mesma mecânica da nota)
  todos                lista as tarefas
  tododone texto       marca uma tarefa como feita
  calc 2+3*4           calculadora rápida
  timer 25             cronômetro de 25 segundos
  weather [cidade]     clima atual
  moon                 fase da lua
  crypto               Bitcoin/Ethereum em USD e BRL
  stocks TICKER        cotação na bolsa
  news                 manchetes do Hacker News em português

GIT
  glog                 histórico gráfico de todos os branches
  gdiff                resumo das mudanças
  gpull                pull com rebase + autostash (seguro)
  gpushf               push force-with-lease (não pisa em ninguém)
  gstash msg           stash com nome · gstashl lista os stashes
  gclean_branches      apaga branches já mesclados
  gci                  commit interativo
  gpr título corpo     cria Pull Request (precisa do gh)
  gsync                sincroniza seu fork com o upstream
  gsub                 atualiza submódulos
  git status           com aviso amigável quando fora de um repositório

ARQUIVOS E REDE
  syncdir origem dest  sincroniza pastas com rsync (valida caminhos)
  backup_dir pasta     tar.gz com data/hora em ~/backups
  download URL         baixa com nome automático
  speedtest            teste de velocidade da internet
  sslinfo dominio      validade e emissor do certificado SSL
  replace a b ext      troca texto em todos os arquivos da extensão
  jsonfmt arquivo      formata JSON · jsonmin minifica
  json2yaml arquivo    converte JSON→YAML · yaml2json o inverso
  urlencode texto      codifica/decodifica texto para URL
  countlines           conta linhas de código do projeto
  spell arquivo        verifica ortografia (aspell): lista erros + sugestões
                       spell -i arquivo  → corrige uma a uma, interativo
  correct              habilita correção ortográfica do zsh (sugere correção de comandos)

PROJETOS (cria tudo pronto em segundos)
  pyproject nome       Python: venv + .gitignore + Dockerfile + git
  nodeproject nome     Node: package.json + Dockerfile + compose + git
  goproject nome       Go: módulo + main.go + git
  rustproject nome     Rust: cargo new + git

MANUTENÇÃO
  updateall            atualiza 12 gerenciadores (pula o que não existe)
  sysclean             limpa caches, logs antigos e thumbnails
  fuck                 corrige o último comando digitado errado
  zest doctor          diagnostica o ambiente completo
  zest add <ferramenta> instala ferramenta sem root (zest add fzf)
  zest update          atualiza tudo (mesma coisa que updateall)

ATALHOS DE TECLADO
  Ctrl+R               busca fuzzy no histórico
  Ctrl+T               busca fuzzy de arquivos
  Alt+C                entra fuzzy em qualquer pasta
  ↑ ↓ (após digitar)   navega o histórico que começa com o que digitou
  z nome-pasta         cd inteligente que aprende seus diretórios
  ESC ESC              repete o comando anterior com sudo
  fuck                 corrige typos: gti stauts → git status

HISTÓRICO
  histnum [N]          lista as últimas N linhas com números (padrão: 30)
                       → use para descobrir o número do comando
  histsed N            apaga UMA linha pelo número (confirma antes)
                       Ex.: histsed 42
  histdel <padrão>     apaga TODAS as linhas que contêm o padrão
                       Ex.: histdel 'senha'   ·   histdel 'api_key'
  histclear            apaga TODO o histórico (pede confirmação)
  histsearch <padrão>  mostra as linhas que contêm o padrão
  histcount            quantas linhas tem o histórico
  histclean           remove duplicatas e linhas vazias

❤️  APOIE O PROJETO: ⚡ nados@speed.app · ₿ bc1q...du5z
    (endereços completos para copiar estão no README do GitHub)
FIM
)
  if [[ -n "$1" ]]; then
    local achou
    achou=$(echo "$body" | grep -i -- "$1") || { echo "nada encontrado para '$1' — tente: ajuda (sem filtro)"; return 1; }
    echo "$achou"
  else
    echo "$body"
  fi
}
