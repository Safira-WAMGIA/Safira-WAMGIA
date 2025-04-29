#!/usr/bin/env bash
###############################################################################
#  run.sh – Safira (stack reduzido + Ollama)                                  #
#  Serviços: n8n · Venom · Whisper · TTS · PostgreSQL · Ollama                #
###############################################################################
set -Eeuo pipefail
trap 'echo -e "\n\e[31m❌ Algo falhou. Veja o log acima.\e[0m"' ERR

# ───── Paleta de cores ──────────────────────────────────────────────────────
BOLD="\e[1m"; DIM="\e[2m"; RESET="\e[0m"
RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"; CYN="\e[36m"
info(){ echo -e "${CYN}[INFO]${RESET} $*"; }
ok(){   echo -e "${GRN}[OK]${RESET}   $*"; }
warn(){ echo -e "${YLW}[WARN]${RESET} $*"; }

# ───── Arquivos principais ─────────────────────────────────────────────────
COMPOSE="docker-compose.yml"
ENV=".env"; ENV_EX=".env.example"

# ───── Flags ───────────────────────────────────────────────────────────────
BUILD=""; RESET=false; STATUS=false; NONINT=false
for arg in "$@"; do case $arg in
  --build) BUILD="--build";;
  --no-build) BUILD="";;
  --reset) RESET=true;;
  --status) STATUS=true;;
  --non-interactive) NONINT=true;;
  *) warn "Flag desconhecida: $arg";;
  esac; done

# ───── Funções auxiliares ──────────────────────────────────────────────────
secret(){ local v=$1; if ! grep -q "^${v}=" "$ENV"; then echo "${v}=" >> "$ENV"; fi; }

# ───── Fluxo especial de reset/status ──────────────────────────────────────
if $RESET;  then info "Resetando stack"; docker compose -f $COMPOSE down -v --remove-orphans; ok "Stack zerado"; exit 0; fi
if $STATUS; then info "Status atual"; docker compose -f $COMPOSE ps;               exit 0; fi

# ───── Pré‑requisitos básicos ──────────────────────────────────────────────
for bin in docker "docker compose" git; do command -v ${bin%% *} >/dev/null || { echo "${RED}${bin} ausente${RESET}"; exit 1; }; done

# ───── .env mínimo ─────────────────────────────────────────────────────────
if [ ! -f "$ENV" ]; then
  [ -f "$ENV_EX" ] && cp "$ENV_EX" "$ENV" && ok "Criado $ENV" || { echo "${RED}Nenhum .env encontrado${RESET}"; exit 1; }
fi
for v in N8N_BASIC_AUTH_PASSWORD POSTGRES_PASSWORD; do secret $v; done

# ───── Validação do compose ────────────────────────────────────────────────
info "Validando YAML..."; docker compose -f $COMPOSE config -q && ok "YAML ok"

# ───── Build / Pull --------------------------------------------------------
if [ -n "$BUILD" ]; then info "Buildando imagens"; docker compose -f $COMPOSE build; else info "Puxando imagens"; docker compose -f $COMPOSE pull || true; fi

# ───── Up ------------------------------------------------------------------
info "Subindo containers"; docker compose -f $COMPOSE up -d --wait --remove-orphans $BUILD
ok "Containers prontos"

# ───── Logs finais bonitões ────────────────────────────────────────────────
printf "\n${BOLD}📊 RESUMO DO STACK${RESET}\n"
docker compose -f $COMPOSE ps --format "table {{.Name}}\t{{.State}}\t{{.PublishedPorts}}"

printf "\n${BOLD}🌐 ENDPOINTS${RESET}\n"
printf "  %-12s → %s\n" "n8n"        "http://localhost:5678"
printf "  %-12s → %s\n" "Venom"      "http://localhost:3000"
printf "  %-12s → %s\n" "Whisper"    "http://localhost:9000"
printf "  %-12s → %s\n" "TTS"        "http://localhost:9001"
printf "  %-12s → %s\n" "PostgreSQL" "localhost:5432"
printf "  %-12s → %s\n" "Ollama"     "http://localhost:11434"

echo -e "\n${GRN}✅ Ambiente Safira rodando.${RESET}\n"