#!/usr/bin/env bash
set -Eeuo pipefail

BOLD="\e[1m"; DIM="\e[2m"; RESET="\e[0m"
RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"; CYN="\e[36m"
log() {
  local lvl="$1"; shift
  while [[ "$1" == "true" || "$1" == "false" ]]; do shift; done
  printf "%b[%-5s]%b %s\n" "$CYN" "$lvl" "$RESET" "$*"
}

cleanup() {
  local code=$?
  [[ $code -ne 0 ]] && echo -e "\n${RED}❌ Script terminou com erro ($code).${RESET}"
  echo -e "${DIM}💡 Shell interativo aberto. Digite 'exit' para sair.${RESET}"
  exec "$SHELL" -l
}
trap cleanup EXIT

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

$RESET  && { log INFO "Resetando stack"; docker compose -f "$COMPOSE" down -v --remove-orphans; exit; }
$STATUS && { docker compose -f "$COMPOSE" ps; exit; }

for cmd in docker "docker compose"; do command -v ${cmd%% *} >/dev/null || { echo -e "${RED}$cmd ausente${RESET}"; exit 1; }; done

[[ -f $ENV_FILE ]] || { [[ -f $ENV_EX ]] && cp "$ENV_EX" "$ENV_FILE"; }

docker compose -f "$COMPOSE" config -q || { echo -e "${RED}YAML inválido${RESET}"; exit 1; }

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

log INFO "Subindo containers"
docker compose -f "$COMPOSE" up -d --remove-orphans || true

echo -e "\n${BOLD}📊 RESUMO${RESET}"
if ! docker compose -f "$COMPOSE" ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}" 2>/dev/null; then
  docker compose -f "$COMPOSE" ps
fi

cat <<EOF

${BOLD}🌐 ENDPOINTS${RESET}
  n8n         → http://localhost:5678
  Venom       → http://localhost:3000
  Whisper     → http://localhost:9000
  TTS         → http://localhost:9001
  PostgreSQL  → localhost:5432
  Ollama      → http://localhost:11434
EOF

SUCCESS=1

if docker compose -f "$COMPOSE" ps --format '{{.Name}} {{.State}}' | \
   grep -Eq 'whisper.*running|whisper.*started' && \
   grep -Eq 'tts.*running|tts.*started'; then
  SUCCESS=0
fi

[[ $SUCCESS -eq 0 ]] && exit 0

$NONINT && exit 0
