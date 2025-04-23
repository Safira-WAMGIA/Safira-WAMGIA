#!/usr/bin/env bash
###############################################################################
# Safira – run.sh (v1-clean-dev)                                              #
#   • Runner único p/ desenvolvimento                                          #
#   • Fica aberto, mostra endpoints + smoke-tests                              #
###############################################################################

# ─── Hard-fail config ────────────────────────────────────────────────────────
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# ─── Variáveis editáveis rápidas ─────────────────────────────────────────────
STACK_NAME="safira"
COMPOSE_FILE="docker-compose.yml"
HEALTH_TIMEOUT=240        # segundos p/ esperar containers ficarem healthy
SMOKE_TIMEOUT=4           # cada curl teste

# ─── Cores ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\e[1m'; CYAN=$'\e[36m'; RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RESET=$'\e[0m'
else
  BOLD=''; CYAN=''; RED=''; GRN=''; YEL=''; RESET=''
fi
log()  { printf "${CYAN}[%(%T)T]${RESET} %b\n" -1 "$*"; }
good() { printf "${GRN}✓ %s${RESET}\n" "$*"; }
fail() { printf "${RED}✖ %s${RESET}\n" "$*" >&2; exit 1; }

# ─── Pausa final (sempre) ────────────────────────────────────────────────────
pause_exit() { [[ -t 0 ]] && { printf "\n${YEL}Pressione qualquer tecla...${RESET}"; read -n1 -s; }; }
trap pause_exit EXIT

# ─── Helpers docker compose ─────────────────────────────────────────────────
DC(){ docker compose -f "$COMPOSE_FILE" "$@"; }
ensure_docker(){ docker info &>/dev/null || fail "Docker daemon parado ou não instalado."; }

wait_healthy(){
  log "⏳ Aguardando containers ficarem healthy (máx ${HEALTH_TIMEOUT}s)..."
  local end=$((SECONDS+HEALTH_TIMEOUT))
  while true; do
    local bad
    bad=$(DC ps --filter "status=running" --format "{{.Service}} {{.Health}}" | awk '$2!="healthy"{print $1}')
    [[ -z $bad ]] && { good "Todos healthy"; return; }
    (( SECONDS > end )) && fail "Timeout aguardando: $bad"
    sleep 2
  done
}

smoke_tests(){
  source .env 2>/dev/null || true
  declare -A URLS=(
    [Safira]="http://localhost:${PORT_SAFIRA:-5678}/healthz"
    [Admin]="http://localhost:${PORT_ADMIN:-5680}/healthz"
    [MinIO]="http://localhost:${PORT_MINIO_CONSOLE:-9001}"
    [Ollama]="http://localhost:${PORT_OLLAMA:-11434}"
  )
  log "🔎 Smoke-tests:"
  for name in "${!URLS[@]}"; do
    url=${URLS[$name]}
    if curl -fsSL --max-time "$SMOKE_TIMEOUT" "$url" >/dev/null; then
      good "$name OK  ($url)"
    else
      printf "${RED}• %s falhou%s  → %s\n" "$name" "$RESET" "$url"
    fi
  done
}

show_endpoints(){
  source .env 2>/dev/null || true
  cat <<EOF

${BOLD}Endpoints úteis:${RESET}
Safira (n8n)    → http://localhost:${PORT_SAFIRA:-5678}
Admin (n8n)     → http://localhost:${PORT_ADMIN:-5680}
MinIO Console   → http://localhost:${PORT_MINIO_CONSOLE:-9001}
Grafana         → http://localhost:${PORT_GRAFANA:-3000}
Traefik dash    → http://localhost (se exposto)
EOF
}

doctor(){
  ensure_docker
  [[ -f .env ]] || fail ".env ausente. Rode setup.sh primeiro."
  DC config >/dev/null || fail "docker-compose.yml inválido."
  good "Compose válido, Docker ok, .env presente."
}

# ─── Commands ───────────────────────────────────────────────────────────────
cmd=${1:-up}; shift || true
case $cmd in
  first)   # primeiro boot “all-in-one”
    ensure_docker
    DC pull
    DC up -d
    wait_healthy
    smoke_tests
    show_endpoints
    ;;
  up)
    ensure_docker
    DC up -d
    wait_healthy
    show_endpoints
    ;;
  down)
    ensure_docker
    DC down
    ;;
  restart)
    ensure_docker
    DC down
    DC up -d
    wait_healthy
    show_endpoints
    ;;
  status)
    ensure_docker
    DC ps --format "table {{.Service}}\t{{.State}}\t{{.Health}}\t{{.PublishedPorts}}"
    ;;
  logs)
    ensure_docker
    svc=${1:-}; [[ -z $svc ]] && fail "Uso: ./run.sh logs <serviço>"
    DC logs -f "$svc"
    ;;
  doctor)  doctor ;;
  help|*)
    cat <<HLP
Uso: ./run.sh <comando>

  first       Primeiro boot: pull + up + tests
  up          Sobe (ou recria se necessário)
  down        Derruba stack
  restart     down + up
  status      Tabela de estado
  logs <svc>  Log follow serviço
  doctor      Diagnóstico rápido
HLP
    ;;
esac
