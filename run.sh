#!/usr/bin/env bash
###############################################################################
#  Safira – run.sh (v5.1)                                                      #
#  • Corrige lista de secrets (remove Supabase, adiciona Redis)                #
#  • Garante permissões na pasta models/venom                                  #
###############################################################################
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# ───── Paleta cores ───────────────────────────────────────────────────────
case "${TERM:-}" in xterm*|screen*|vt*) BOLD="\e[1m" CYAN="\e[36m" RED="\e[31m" RESET="\e[0m";; *) BOLD="" CYAN="" RED="" RESET="";; esac
info(){  printf "%b%s%b\n" "$CYAN" "$1" "$RESET"; }
error(){ printf "%b%s%b\n" "$RED"  "$1" "$RESET" >&2; }
banner(){ info "\n$1"; }
trap 'error "\n❌ Algo deu errado."; read -n1 -s -r -p "🔁  Pressione qualquer tecla…"; exit 1' ERR

# ───── Argparse ─────────────────────────────────────────────────────────--
action=${1:-help}; shift || true
dev=false; nobuild=false; save_logs=false; profile=""; svc=""; prune_soft=false
while [[ $# -gt 0 ]]; do case $1 in
  --dev)      dev=true ;;
  --no-build) nobuild=true ;;
  --save)     save_logs=true ;;
  soft)       prune_soft=true ;;
  *) if [[ -z $profile && $action =~ ^(up|restart)$ && ! $1 =~ ^- ]]; then profile=$1
     elif [[ -z $svc && $action == logs ]]; then svc=$1
     else error "Argumento desconhecido: $1"; exit 1; fi ;;
esac; shift; done
valid_cmds="up down restart status logs prune profiles completion help"
if ! grep -qw "$action" <<<"$valid_cmds"; then error "Uso: $0 <${valid_cmds// /|}> [options]"; exit 1; fi

# ───── Pré‑requisitos ─────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || { error "Docker não instalado."; exit 1; }
if ! docker info >/dev/null 2>&1; then error "Docker daemon parado."; exit 1; fi
if command -v docker-compose >/dev/null 2>&1; then DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1;  then DOCKER_COMPOSE="docker compose"
else error "docker compose não encontrado."; exit 1; fi

# ───── Helpers ────────────────────────────────────────────────────────────
ENSURE_DIRS=(backup shared docs models/venom)
ensure_dirs(){ for d in "${ENSURE_DIRS[@]}"; do [[ -d $d ]] || mkdir -p "$d"; done }
fix_permissions(){ for d in "${ENSURE_DIRS[@]}"; do sudo chown -R "$(id -u):$(id -g)" "$d" || true; done }

compose(){ $DOCKER_COMPOSE ${profile:+--profile "$profile"} "$@"; }
validate_config(){ compose --env-file .env config >/dev/null; }
compose_pull(){ $nobuild || compose pull --quiet; }
compose_up(){ validate_config; compose_pull; compose up -d ${nobuild:+} ${nobuild:+}; }
compose_down(){ compose down --remove-orphans --timeout 20; }
compose_status(){ compose ps --format "table {{.Service}}\t{{.State}}\t{{.PublishedPorts}}"; }

wait_healthy(){
  banner "⏳  Aguardando serviços ficarem healthy…"
  end=$((SECONDS+300))
  while true; do
    unhealthy=$(compose ps --filter "status=running" --filter "status=starting" --format "{{.Service}} {{.Health}}" | awk '$2!="healthy"{print $1}')
    [[ -z $unhealthy ]] && break
    (( SECONDS > end )) && { error "Timeout aguardando: $unhealthy"; exit 1; }
    sleep 2
  done
  info "✅ Todos os serviços healthy"
}

check_files(){
  local missing=(); for f in .env prometheus/prometheus.yml traefik/traefik.yml loki/loki-config.yaml docs/docs/index.md docs/mkdocs.yml; do [[ -f $f ]]||missing+=("$f"); done
  ((${#missing[@]})) && { error "Arquivos faltantes: ${missing[*]} (rode ./setup.sh)"; exit 1; }
}
check_secrets(){
  local expected=(pg_safira_pwd pg_pagamento_pwd pg_jira_pwd minio_pwd grafana_pwd traefik_pwd redis_pwd jenkins_admin_pwd)
  local miss=(); for s in "${expected[@]}"; do docker secret inspect "$s" >/dev/null 2>&1 || miss+=("$s"); done
  ((${#miss[@]})) && { error "Secrets ausentes: ${miss[*]}"; exit 1; }
}

$dev || { check_files; check_secrets; }
ensure_dirs; fix_permissions

show_endpoints(){ source .env || true; cat <<EOF
Safira (n8n)  http://localhost:${PORT_SAFIRA:-5678}
Admin (n8n)   http://localhost:${PORT_ADMIN:-5680}
Venom API     http://localhost:${PORT_VENOM:-3001}
STT           http://localhost:${PORT_STT:-9000}
CSM/TTS       http://localhost:${PORT_CSM:-5050}
Ollama        http://localhost:${PORT_OLLAMA:-11434}
EOF
}
list_profiles(){ banner "📂  Profiles disponíveis"; grep -A1 '^profiles:' -n docker-compose.yml | awk -F: '/^ *[a-zA-Z0-9_-]+:$/ {print $2}' | sort -u; }
completion_script(){ cat <<'BASH'
_complete_safira(){
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -W "up down restart status logs prune profiles completion help" -- "$cur") )
}
complete -F _complete_safira run.sh
BASH
}

case $action in
  up)       banner "🚀  Subindo stack (profile: ${profile:-default})"; compose_up; wait_healthy; show_endpoints ;;
  down)     banner "🛑  Derrubando stack"; compose_down ;;
  restart)  compose_down; compose_up; wait_healthy ;;
  status)   compose_status; compose ps --filter "status=exited" && true ;;
  logs)     [[ -z $svc ]] && { error "Informe ./run.sh logs <service> [--save]"; exit 1; };
            $save_logs && compose logs "$svc" > "logs/${svc}_$(date +%F_%H%M).log" && info "📝 Logs salvos" || compose logs -f "$svc" ;;
  prune)    $prune_soft && { docker image prune -f; docker container prune -f; } || docker system prune -f --volumes ;;
  profiles) list_profiles ;;
  completion) completion_script ;;
  help) echo "Ver README" ;;
esac

read -n 1 -s -r -p "🚀 Pressione qualquer tecla para sair..."
