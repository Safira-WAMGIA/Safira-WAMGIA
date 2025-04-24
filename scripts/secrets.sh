#!/usr/bin/env bash
###############################################################################
#  Safira – set_secrets.sh
#  • Cria ou atualiza todos os Docker secrets exigidos pelo stack
#  • Gera valor aleatório seguro quando o usuário apenas pressiona ENTER
#  • Mantém idempotência: se o secret existe, pergunta antes de sobrescrever
###############################################################################
set -euo pipefail

# --- lista nome → prompt ---
declare -A SECRET_PROMPTS=(
  [pg_safira_pwd]="Senha do Postgres (db-safira)"
  [pg_pagamento_pwd]="Senha do Postgres (db-pagamento)"
  [pg_jira_pwd]="Senha do Postgres (db-jira)"
  [minio_pwd]="Senha root do MinIO"
  [grafana_pwd]="Senha admin do Grafana"
  [traefik_pwd]="Linha htpasswd (user:senha) p/ Traefik dashboard  (deixe em branco para gerar user=admin)"
  [supa_db_pwd]="Senha interna do banco Supabase"
  [jwt_secret]="JWT_SECRET Supabase (32 hex)      "
  [anon_key]="ANON_KEY Supabase (32 hex)          "
  [service_role_key]="SERVICE_ROLE_KEY Supabase (32 hex)"
  [redis_pwd]="Senha do Redis (opcional)          "
  [jenkins_admin_pwd]="Senha admin do Jenkins      "
)

# --- funções auxiliares ---
generate_random() { openssl rand -hex 32; }
generate_htpasswd() {
  local pw="$1"
  printf "admin:$(openssl passwd -apr1 "$pw")"
}

secret_exists() { docker secret ls --quiet --filter name="$1" | grep -q .; }

###############################################################################
echo -e "\n🛡️  SETUP DE SECRETS SAFIRA\n──────────────────────────────"

for secret in "${!SECRET_PROMPTS[@]}"; do
  prompt="${SECRET_PROMPTS[$secret]}"
  default_action="generate"

  # Se já existe, confirmar overwrite
  if secret_exists "$secret"; then
    read -rp "Secret '$secret' já existe. Substituir? [s/N] " confirm
    [[ ! $confirm =~ ^[sS]$ ]] && { echo "• Mantido"; continue; }
  fi

  # Entrada silenciosa
  read -srp "$prompt: " value; echo
  if [[ -z "$value" ]]; then
    case "$secret" in
      traefik_pwd)
        rnd_pass=$(generate_random | head -c 12)
        value=$(generate_htpasswd "$rnd_pass")
        echo "  → htpasswd gerado (user=admin, senha=$rnd_pass)"
        ;;
      jwt_secret|anon_key|service_role_key)
        value=$(generate_random)
        echo "  → Valor aleatório gerado"
        ;;
      *)
        value=$(generate_random | head -c 24)
        echo "  → Senha aleatória gerada"
        ;;
    esac
  fi

  # (Re)criar segredo
  secret_exists "$secret" && docker secret rm "$secret" >/dev/null
  echo -n "$value" | docker secret create "$secret" - >/dev/null
  echo "  ✓ Secret '$secret' criado/atualizado"
done

echo -e "\n✅  Todos os secrets configurados!"
read -n 1 -s -r -p "🚨 Pressione qualquer tecla para fechar..."