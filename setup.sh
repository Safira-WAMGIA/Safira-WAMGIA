#!/usr/bin/env bash
###############################################################################
#  Safira – setup.sh (v2‑stable)                                               #
#                                                                              #
#  • Cria pastas locais                                                        #
#  • Gera configs default                                                      #
#  • Scaffold Docker/Python para serviços custom                               #
#  • Copia .env de exemplo (ou gera template)                                  #
#  • Provisiona Docker secrets (pula em ‑‑dev ou se Swarm inativo)             #
#  • Pull & valida docker‑compose                                              #
###############################################################################
set -Eeuo pipefail
trap 'echo -e "\n❌ Algo deu errado durante a execução."; \
echo "Comando com erro: $BASH_COMMAND"; \
echo "\nPressione Enter para sair..."; \
read; \
exit 1' ERR

banner(){ echo -e "\n\033[1;36m$1\033[0m"; }

# ───── CLI flags ──────────────────────────────────────────────────────────
DEV=false  # ignora Swarm / secrets
while [[ $# -gt 0 ]]; do case $1 in --dev) DEV=true ;; *) ;; esac; shift; done

# ───── Swarm automático ───────────────────────────────────────────────────
if ! $DEV; then
  SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')
  if [[ $SWARM_STATE != active ]]; then
    banner "⚙️  Swarm não iniciado – ativando automaticamente"
    docker swarm init >/dev/null && echo "✓ Swarm iniciado"
  fi
fi

# ───── Dependências ───────────────────────────────────────────────────────
banner "🔍  Dependências"
command -v docker >/dev/null 2>&1 || { echo "Docker não instalado."; exit 1; }
if command -v docker-compose >/dev/null 2>&1; then DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then DOCKER_COMPOSE="docker compose"
else echo "docker compose não encontrado."; exit 1; fi
echo "✅ Usando '$DOCKER_COMPOSE'"

# ───── Pastas projeto ─────────────────────────────────────────────────────
banner "📁  Diretórios de build"
DIRS=(backup csm venom voice/input image/input image/output ai-functions \
      traefik loki prometheus docs/docs shared models/venom)
for d in "${DIRS[@]}"; do [[ -d $d ]] || { mkdir -p "$d" && echo "• $d/ criado"; }; done

# ───── Configs default ────────────────────────────────────────────────────
banner "📝  Arquivos de configuração"
create_if_absent(){ [[ -s $1 ]] || { printf '%s\n' "$2" > "$1" && echo "• $1"; }; }
create_if_absent loki/loki-config.yaml 'auth_enabled: false\nserver:\n  http_listen_port: 3100'
create_if_absent prometheus/prometheus.yml 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs: [{ targets: ["localhost:9090"] }]'
create_if_absent traefik/traefik.yml 'entryPoints:\n  web: { address: ":80" }\n  websecure: { address: ":443" }\napi: { dashboard: true }\nproviders:\n  docker: { exposedByDefault: false }\nlog: { level: ${TRAEFIK_LOG_LEVEL:-INFO} }'
create_if_absent docs/mkdocs.yml 'site_name: Safira Docs\ntheme: { name: material }\nnav: [ { Inicio: index.md } ]'
create_if_absent docs/docs/index.md '# Bem‑vindo à documentação da Safira'

# ───── Scaffold serviços Python ─────────────────────────────────────────--
banner "🐍  Scaffold Docker/Python"
DOCKERFILE_TPL=$(cat <<'DOCKER'
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gcc ffmpeg libsndfile1 git curl && rm -rf /var/lib/apt/lists/*
ENV APP_USER=app
RUN useradd -ms /bin/bash $APP_USER
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN chown -R $APP_USER:$APP_USER /app
USER $APP_USER
HEALTHCHECK CMD curl -f http://localhost:${HEALTH_PORT:-8000}/healthz || exit 1
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER
)

REQS_TPL=$(cat <<'REQ'
fastapi>=0.110,<0.111
uvicorn[standard]>=0.29,<0.30
python-dotenv
pydantic
requests
REQ
)

ENTRYPOINT_TPL=$(cat <<'ENT'
#!/usr/bin/env bash
set -e
[[ -f /app/bootstrap.sh ]] && bash /app/bootstrap.sh
exec "$@"
ENT
)

MAIN_TPL=$(cat <<'PY'
from fastapi import FastAPI
app = FastAPI()
@app.get('/healthz', include_in_schema=False)
def healthz():
    return {'status': 'ok'}
@app.get('/')
def root():
    return {'msg': '🚀 Safira service booting!'}
PY
)

for svc in venom csm voice/input image/input image/output ai-functions backup; do
  [[ -f $svc/Dockerfile ]]      || { printf '%s\n' "$DOCKERFILE_TPL"  > "$svc/Dockerfile"; echo "• Dockerfile → $svc/"; }
  [[ -f $svc/requirements.txt ]]|| { printf '%s\n' "$REQS_TPL"       > "$svc/requirements.txt"; }
  [[ -f $svc/.dockerignore ]]   || { printf '%s\n' "__pycache__\n*.py[cod]\n*.log\n.venv\n.env\n.git" > "$svc/.dockerignore"; }
  [[ -f $svc/entrypoint.sh ]]   || { printf '%s\n' "$ENTRYPOINT_TPL" > "$svc/entrypoint.sh"; chmod +x "$svc/entrypoint.sh"; }
  [[ -f $svc/main.py ]]         || printf '%s\n' "$MAIN_TPL" > "$svc/main.py"
done

# ───── .env file ─────────────────────────────────────────────────────────-
banner "🔑  .env"
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then cp .env.example .env
  else
    cat > .env <<'ENV'
# Portas
PORT_MINIO_API=9000
PORT_MINIO_CONSOLE=9001
PORT_SAFIRA=5678
PORT_ADMIN=5680
# Credenciais
POSTGRES_USER=postgres
MINIO_ROOT_USER=minio
TZ=America/Sao_Paulo
ENV
    echo "• .env gerado com valores base"
  fi
else
  echo "• .env já existe"
fi

# ───── Docker secrets ─────────────────────────────────────────────────────
if ! $DEV; then
  SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')
  if [[ $SWARM_STATE != active ]]; then
    banner "⚠️  Swarm inativo – pulando secrets (modo dev)"
  else
    banner "🔐  Secrets"
    SECRETS=(pg_safira_pwd pg_pagamento_pwd pg_jira_pwd minio_pwd grafana_pwd traefik_pwd redis_pwd jenkins_admin_pwd)
    existing=$(docker secret ls --format '{{.Name}}')
    for s in "${SECRETS[@]}"; do
      if grep -qx "$s" <<<"$existing"; then echo "• $s (ok)"; else
        read -rsp "Valor para '$s' (Enter = aleatório) : " val; echo
        [[ -z $val ]] && val=$(openssl rand -hex 16)
        echo -n "$val" | docker secret create "$s" - >/dev/null
        echo "  ✓ $s criado"
      fi
    done
  fi
else
  banner "🔓  --dev flag ativa – ignorando secrets"
fi


# ───── Pull & validação (modo Swarm ou compose) ──────────────────────────
banner "🐳  Validando stack"
if $DEV; then
  $DOCKER_COMPOSE pull --quiet
  $DOCKER_COMPOSE --env-file .env config >/dev/null
else
  docker stack deploy --compose-file docker-compose.yml safira --prune
  docker stack services safira
fi


banner "🎉  Setup concluído"
echo "Execute:  $DOCKER_COMPOSE up -d (ou ./run.sh up)"

# ───── Espera por tecla antes de fechar ──────────────────────────────────
echo "\n🚀 Pressione Enter para sair..."
read

