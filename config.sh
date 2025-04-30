#!/usr/bin/env bash
set -Eeuo pipefail

# Cores e log
CYN="\e[36m"; RED="\e[31m"; GRN="\e[32m"; RESET="\e[0m"
log() { printf "%b[CONFIG]%b %s\n" "$CYN" "$RESET" "$1"; }
err() { printf "%b[ERRO]%b %s\n" "$RED" "$RESET" "$1" >&2; }

# Sempre manter terminal aberto ao final
cleanup() {
  local code=$?
  if [[ $code -ne 0 ]]; then
    echo -e "\n${RED}❌ Script terminou com erro ($code).${RESET}"
  else
    echo -e "\n${GRN}✅ Script concluído com sucesso.${RESET}"
  fi
  echo -e "${CYN}💡 Shell interativo aberto. Digite 'exit' para sair.${RESET}"
  exec "$SHELL" -l
}
trap cleanup EXIT

# Carrega variáveis do .env
ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  err ".env não encontrado"
  return 1
fi

# ───── Verifica e cria bancos de dados ───────────────────────────────
DB_CONTAINER="Safira-DB"
DB_USER="postgres"
DB_PASS="${POSTGRES_PASSWORD:-}"
DB_NAMES=("jiradb" "wikidb")

log "🔍 Verificando bancos de dados no container '$DB_CONTAINER'..."

if ! docker ps --format '{{.Names}}' | grep -q "$DB_CONTAINER"; then
  err "Container do banco ($DB_CONTAINER) não está rodando"
  return 1
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
MODELOS=(
  "llama3.2"
  "llama3.1:8b"
  "llama3:instruct"
)

if ! docker ps --format '{{.Names}}' | grep -q "$OLLAMA_CONTAINER"; then
  err "Container Ollama ($OLLAMA_CONTAINER) não está rodando"
  return 1
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
