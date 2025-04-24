#!/usr/bin/env bash
###############################################################################
#  clean_docker.sh – “formata” seu Docker local                                #
#                                                                              #
#  Uso rápido……  ./clean_docker.sh                # limpa tudo, exceto volumes #
#                ./clean_docker.sh --nuke-volumes # inclui volumes             #
#                                                                              #
#  O que faz:                                                                   #
#    1) Sai (forçado) do Swarm e remove stacks/serviços                        #
#    2) Mata e remove TODOS os containers                                      #
#    3) Prune de images não usadas (ou todas, se --all-images)                 #
#    4) Remove networks órfãs                                                  #
#    5) Limpa build-cache                                                      #
#    6) (opcional) Prune de volumes                                            #
###############################################################################
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# ──────────── Estética ──────────────────────────────────────────────────────
case "${TERM:-}" in xterm*|screen*|vt*) BOLD=$'\e[1m'; GREEN=$'\e[32m'; RED=$'\e[31m'; RESET=$'\e[0m';; *) BOLD=""; GREEN=""; RED=""; RESET="";; esac
log(){ printf "%b%s%b\n" "$GREEN" "$1" "$RESET"; }
die(){ printf "%b%s%b\n" "$RED" "❌ $1" "$RESET" >&2; exit 1; }

NUKE_VOLUMES=false
ALL_IMAGES=false

for arg in "$@"; do
  case "$arg" in
    --nuke-volumes) NUKE_VOLUMES=true ;;
    --all-images)   ALL_IMAGES=true   ;;
    -h|--help)
      cat <<EOF
Uso: ./clean_docker.sh [--nuke-volumes] [--all-images]

  --nuke-volumes   Remove TODOS os volumes (dado persistente) – perigoso!
  --all-images     Apaga TODAS as images, mesmo que estejam em uso por compose
EOF
      exit 0 ;;
    *) die "Flag desconhecida: $arg";;
  esac
done

# ──────────── Mata Swarm (se existir) ───────────────────────────────────────
if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qiE 'active|pending'; then
  log "⛵  Saindo do Swarm e limpando stacks/serviços…"
  docker stack ls --format '{{.Name}}' | while read -r stack; do
    [ -n "$stack" ] && docker stack rm "$stack" || true
  done
  # Aguarda até que todos os serviços sumam
  while [ "$(docker service ls -q | wc -l)" -gt 0 ]; do sleep 1; done
  docker swarm leave --force || true
fi

# ──────────── Containers ────────────────────────────────────────────────────
if [ "$(docker ps -aq | wc -l)" -gt 0 ]; then
  log "🛑  Parando containers…"
  docker container stop $(docker ps -aq) || true
  log "🧹  Removendo containers…"
  docker container rm -f $(docker ps -aq) || true
fi

# ──────────── Networks órfãs ────────────────────────────────────────────────
log "🔌  Limpando networks órfãs…"
docker network prune -f || true

# ──────────── Imagens ───────────────────────────────────────────────────────
if $ALL_IMAGES; then
  log "🖼️  Removendo TODAS as images…"
  docker image rm -f $(docker image ls -aq) 2>/dev/null || true
else
  log "🖼️  Removendo images não usadas (dangling)…"
  docker image prune -af || true
fi

# ──────────── Builder cache ────────────────────────────────────────────────
log "🛠️  Limpando builder cache…"
docker builder prune -af || true

# ──────────── Volumes (opcional) ────────────────────────────────────────────
if $NUKE_VOLUMES; then
  log "💣  Removendo TODOS os volumes…"
  docker volume prune -f || true
fi

# ──────────── Final ────────────────────────────────────────────────────────
log "✅  Docker limpo! Execute 'docker system df' para conferir espaço liberado."
