# zest :: 47-projects — módulo do Zest (extraído e testado na prática)
#  FUNÇÕES — Criar projetos completos em segundos
# ------------------------------------------------------------
nodeproject() {
  local name="${1:-my-project}"
  mkdir -p "$name" && cd "$name"
  command -v npm >/dev/null 2>&1 && npm init -y
  cat > .gitignore << 'EOF'
node_modules/
dist/
.env
*.log
.DS_Store
EOF
  cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
EOF
  cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
EOF
  git init -q
  echo "✅ Projeto Node criado: $name"
}

pyproject() {
  local name="${1:-my-project}"
  mkdir -p "$name" && cd "$name"
  python3 -m venv .venv
  cat > .gitignore << 'EOF'
.venv/
__pycache__/
*.pyc
.env
dist/
*.egg-info/
.pytest_cache/
EOF
  printf '# Adicione suas dependências aqui\n' > requirements.txt
  cat > main.py << 'EOF'
def main():
    print("Hello, World!")

if __name__ == "__main__":
    main()
EOF
  cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "main.py"]
EOF
  git init -q
  echo "✅ Projeto Python criado: $name (ative com: source .venv/bin/activate)"
}

goproject() {
  local name="${1:-my-project}"
  if ! command -v go >/dev/null 2>&1; then echo "go não instalado (use: mise use go)"; return 1; fi
  mkdir -p "$name" && cd "$name"
  go mod init "$name"
  cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF
  printf 'bin/\n*.exe\n*.test\nvendor/\n' > .gitignore
  git init -q
  echo "✅ Projeto Go criado: $name"
}

rustproject() {
  local name="${1:-my-project}"
  if ! command -v cargo >/dev/null 2>&1; then echo "cargo não instalado (use: mise use rust)"; return 1; fi
  cargo new "$name" && cd "$name"
  echo "✅ Projeto Rust criado: $name"
}

# ------------------------------------------------------------
