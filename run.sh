#!/usr/bin/env bash
set -Eeuo pipefail

# Estética
BOLD="\e[1m"; DIM="\e[2m"; RESET="\e[0m"
RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"; CYN="\e[36m"
log() {
  local lvl="$1"; shift
  while [[ "$1" == "true" || "$1" == "false" ]]; do shift; done
  printf "%b[%-5s]%b %s\n" "$CYN" "$lvl" "$RESET" "$*"
}

# Trap de erro com shell interativo
cleanup() {
  local code=$?
  [[ $code -ne 0 ]] && echo -e "\n${RED}❌ Script terminou com erro ($code).${RESET}"
  echo -e "${DIM}💡 Shell interativo aberto. Digite 'exit' para sair.${RESET}"
  exec "$SHELL" -l
}
trap cleanup EXIT

# Flags
COMPOSE="docker-compose.yml"
ENV_FILE=".env"; ENV_EX=".env.example"
BUILD=false; UP_ONLY=false; RESET=false; STATUS=false; NONINT=false
for arg in "$@"; do case $arg in
  --build) BUILD=true;;
  --up)    UP_ONLY=true;;
  --reset) RESET=true;;
  --status) STATUS=true;;
  --non-interactive) NONINT=true;;
  *) log WARN "Flag desconhecida: $arg";;
esac; done

# Pré-validação de comandos
for cmd in docker "docker compose"; do
  command -v ${cmd%% *} >/dev/null || { echo -e "${RED}$cmd ausente${RESET}"; exit 1; }
done

# .env fallback
[[ -f $ENV_FILE ]] || { [[ -f $ENV_EX ]] && cp "$ENV_EX" "$ENV_FILE"; }

# YAML check
docker compose -f "$COMPOSE" config -q || { echo -e "${RED}YAML inválido${RESET}"; exit 1; }

# Ações únicas
if $RESET; then
  log INFO "Resetando stack"
  docker compose -f "$COMPOSE" down -v --remove-orphans
  exit 0
fi

if $STATUS; then
  docker compose -f "$COMPOSE" ps
  exit 0
fi

# Build ou Pull
if ! $UP_ONLY; then
  if $BUILD; then
    log INFO "Rebuild completo (--build)"
    docker compose -f "$COMPOSE" build || true
  else
    log INFO "Pulling imagens"
    if ! docker compose -f "$COMPOSE" pull; then
      log WARN "Pull falhou; usando imagens locais"
    fi
  fi
else
  log INFO "--up ativo: pulando pull/build"
fi

# Subindo stack
log INFO "Subindo containers"
docker compose -f "$COMPOSE" up -d --remove-orphans || true

# Resumo visual
echo -e "\n📊 ${BOLD}RESUMO${RESET}"
if ! docker compose -f "$COMPOSE" ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}" 2>/dev/null; then
  docker compose -f "$COMPOSE" ps
fi

# Endpoints úteis
cat <<EOF

🌐 ENDPOINTS
  n8n         → http://localhost:5678
  Jira        → http://localhost:8080
  WikiJS      → http://localhost:3001
EOF

SUCCESS=1

# Verifica se whisper e tts estão rodando
if docker compose -f "$COMPOSE" ps --format '{{.Name}} {{.State}}' | grep -Eq 'whisper.*running|whisper.*started' && \
   docker compose -f "$COMPOSE" ps --format '{{.Name}} {{.State}}' | grep -Eq 'tts.*running|tts.*started'; then
  SUCCESS=0
fi

# Aguarda containers essenciais ficarem prontos
REQUIRED_CONTAINERS=("Safira-DB" "Safira-Ollama")
TIMEOUT=90
INTERVAL=5
elapsed=0

log INFO "Aguardando containers essenciais ficarem prontos..."

while true; do
  ready=true
  for container in "${REQUIRED_CONTAINERS[@]}"; do
    state=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unavailable")
    # Se for unhealthy ou indisponível, avisar e aguardar
    if [[ "$state" == "exited" || "$state" == "dead" || "$state" == "unavailable" ]]; then
      log WARN "Aguardando '$container' (estado crítico: $state)"
      ready=false

    # Se estiver apenas em starting, toleramos dentro do timeout
    elif [[ "$state" == "starting" ]]; then
      log INFO "Aguardando '$container' (estado: $state)"
      ready=false
    else
      log INFO "✅ '$container' está pronto (estado: $state)"
    fi

  done

  if $ready; then
    log INFO "✅ Todos os containers essenciais estão prontos"
    break
  fi

  sleep "$INTERVAL"
  ((elapsed+=INTERVAL))
  if (( elapsed >= TIMEOUT )); then
    log ERROR "⏰ Timeout: containers não ficaram prontos em $TIMEOUT segundos"
    exit 1
  fi
done

# Log e variáveis
CYN="\e[36m"; RED="\e[31m"; GRN="\e[32m"; RESET="\e[0m"
log() { printf "%b[CONFIG]%b %s\n" "$CYN" "$RESET" "$1"; }
err() { printf "%b[ERRO]%b %s\n" "$RED" "$RESET" "$1" >&2; }

# Carrega variáveis do .env
ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  err ".env não encontrado"
  exit 1
fi

# ───── Verifica e cria bancos de dados ───────────────────────────────
DB_CONTAINER="Safira-DB"
DB_USER="postgres"
DB_PASS="${POSTGRES_PASSWORD:-}"
DB_NAMES=("jiradb" "wikidb")

log "🔍 Verificando bancos de dados no container '$DB_CONTAINER'..."

if ! docker ps --format '{{.Names}}' | grep -q "$DB_CONTAINER"; then
  err "Container do banco ($DB_CONTAINER) não está rodando"
  exit 1
fi

for db in "${DB_NAMES[@]}"; do
  log "Verificando banco '$db'..."
  EXISTS=$(docker exec -e PGPASSWORD="$DB_PASS" "$DB_CONTAINER" \
    psql -U "$DB_USER" -tAc "SELECT 1 FROM pg_database WHERE datname = '$db';")

  if [[ "$EXISTS" == "1" ]]; then
    log "✅ Banco '$db' já existe"
  else
    log "🔧 Criando banco '$db'..."
    docker exec -e PGPASSWORD="$DB_PASS" "$DB_CONTAINER" \
      psql -U "$DB_USER" -c "CREATE DATABASE \"$db\";"
    log "✅ Banco '$db' criado com sucesso"
  fi
done

# ───── Verifica e baixa modelos no Ollama ────────────────────────────
log "🔍 Verificando e puxando modelos no Ollama..."

OLLAMA_CONTAINER="Safira-Ollama"
MODELOS=("llama3.2" "llama3.1:8b" "llama3:instruct")

if ! docker ps --format '{{.Names}}' | grep -q "$OLLAMA_CONTAINER"; then
  err "Container Ollama ($OLLAMA_CONTAINER) não está rodando"
  exit 1
fi

for modelo in "${MODELOS[@]}"; do
  log "🔎 Checando modelo '$modelo'..."
  if docker exec "$OLLAMA_CONTAINER" ollama list | awk '{print $1}' | grep -qx "$modelo"; then
    log "✅ Modelo '$modelo' já está disponível"
  else
    log "⬇️  Fazendo pull do modelo '$modelo'..."
    docker exec "$OLLAMA_CONTAINER" ollama pull "$modelo" || {
      err "❌ Falha ao puxar '$modelo'"
      exit 1
    }
    log "✅ Modelo '$modelo' baixado com sucesso"
  fi
done

if [[ $SUCCESS -eq 0 ]]; then
  exit 0
fi

if $NONINT; then
  exit 0
fi
