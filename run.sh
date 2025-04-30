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

if [[ $SUCCESS -eq 0 ]]; then
  exit 0
fi

if $NONINT; then
  exit 0
fi
