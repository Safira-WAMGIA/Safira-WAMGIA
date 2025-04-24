set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
trap 'echo -e "
❌ Erro durante execução. Verifique os logs acima."; read -n 1 -s -r -p "
🔁 Pressione qualquer tecla para sair..."' ERR

# ───── Cores ────────────────────────────────────────────────────────────────
BOLD="\e[1m"; GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"
echo_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
echo_done() { echo -e "${GREEN}[OK]${RESET} $1"; }
echo_error() { echo -e "${RED}[ERRO]${RESET} $1"; }

# ───── Flags ─────────────────────────────────────────────────────────────────
BUILD_FLAG="--build"
RESET_FLAG=false
STATUS_FLAG=false
ONLY=""

for arg in "$@"; do
  case $arg in
    --no-build) BUILD_FLAG="";;
    --reset) RESET_FLAG=true;;
    --status) STATUS_FLAG=true;;
    --only-core) ONLY="core venom postgres";;
    --only-ai) ONLY="ollama sesame whisper coqui blip2 auto1111";;
  esac
  shift
done

# ───── Reset Completo ───────────────────────────────────────────────────────
if [ "$RESET_FLAG" = true ]; then
  echo_info "Resetando ambiente Safira (containers, volumes e rede)..."
  docker compose down -v --remove-orphans || true
  docker network rm safira-net 2>/dev/null || true
  echo_done "Ambiente limpo."
  exit 0
fi

# ───── Status apenas ────────────────────────────────────────────────────────
if [ "$STATUS_FLAG" = true ]; then
  docker compose ps
  exit 0
fi


# ───── Validando pré-requisitos ─────────────────────────────────────────────
echo_info "Verificando dependências..."
command -v docker >/dev/null || { echo_error "Docker não está instalado."; exit 1; }
command -v docker compose >/dev/null || { echo_error "Docker Compose V2 não encontrado."; exit 1; }

# ───── Preparando ambiente inicial ──────────────────────────────────────────
echo_info "Verificando arquivo .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo_done ".env gerado a partir do .env.example"
else
  echo_done ".env já existe"
fi
# ───── Preenchendo variáveis de senha interativamente se estiverem vazias ──
echo_info "Validando variáveis sensíveis no .env"

ensure_secret() {
  local var="$1"
  local default="$2"
  if ! grep -q "^${var}=" .env; then
    echo "${var}=${default}" >> .env
  fi
  local value=$(grep "^${var}=" .env | cut -d '=' -f2-)
  if [ -z "$value" ]; then
    read -rp "🔐 Informe um valor para ${var}: " input
    sed -i "s/^${var}=.*\$/${var}=${input}/" .env
    echo_done "${var} definido"
  fi
}

for var in N8N_BASIC_AUTH_PASSWORD REDIS_PASSWORD MINIO_ROOT_PASSWORD POSTGRES_PASSWORD GRAFANA_ADMIN_PASSWORD JENKINS_ADMIN_PASSWORD SD_API_KEY; do
  ensure_secret "$var" ""
done

# ───── Criando estrutura de diretórios essenciais ────────────────
echo_info "Garantindo estrutura mínima de pastas e arquivos..."

DIRS=(
  ./build/core
  ./build/venom
  ./build/ollama
  ./build/sesame
  ./build/whisper
  ./build/coqui
  ./build/prometheus
  ./build/grafana
  ./build/traefik
  ./build/nginxs
  ./build/redis
  ./build/minio
  ./build/jira
  ./build/jenkins
  ./build/blip2
  ./build/auto1111
  ./db
  ./workflows
  ./docs
  ./scripts
)

for dir in "${DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo_info "📁 Criado: $dir"
  fi

done

# ───── Criando Dockerfile e main.py para serviços personalizados ────────────────


echo_info "Verificando arquivos base para o serviço Venom..."
VENOM_PATH=./build/venom

# Criar package.json se não existir
if [ ! -f "$VENOM_PATH/package.json" ]; then
  cat <<EOF > "$VENOM_PATH/package.json"
{
  "name": "safira-whatsapp",
  "version": "1.0.0",
  "main": "main.js",
  "type": "module",
  "dependencies": {
    "venom-bot": "^5.1.0"
  }
}
EOF
  echo_info "📦 package.json criado para o serviço Venom"
fi


if [ ! -f "$VENOM_PATH/main.js" ]; then
  cat <<EOF > "$VENOM_PATH/main.js"
const { create } = require('venom-bot');

create().then((client) => {
  client.onMessage((message) => {
    console.log('Mensagem recebida:', message.body);
    if (message.body && message.isGroupMsg === false) {
      client.sendText(message.from, 'Olá! Aqui é a Safira ✨');
    }
  });
});
EOF
  echo_info "🔧 main.js criado para o serviço Venom"
fi

if [ ! -f "$VENOM_PATH/Dockerfile" ]; then
  cat <<EOF > "$VENOM_PATH/Dockerfile"
FROM node:18-alpine
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000
CMD ["node", "main.js"]

EOF
  echo_info "📦 Dockerfile criado para o serviço Venom"
fi

# Coqui
echo_info "Verificando arquivos base para o serviço Coqui..."
COQUI_PATH=./build/coqui
if [ ! -f "$COQUI_PATH/main.py" ]; then
  cat <<EOF > "$COQUI_PATH/main.py"
from TTS.api import TTS
from flask import Flask, request, send_file
import uuid
import os

app = Flask(__name__)
tts = TTS(model_name=os.getenv("COQUI_MODEL", "tts_models/en/ljspeech/tacotron2-DDC"), progress_bar=False, gpu=False)

@app.route("/speak", methods=["POST"])
def speak():
    text = request.json.get("text", "")
    if not text:
        return {"error": "No text provided"}, 400
    output_path = f"/tmp/{uuid.uuid4()}.wav"
    tts.tts_to_file(text=text, file_path=output_path)
    return send_file(output_path, mimetype="audio/wav")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9001)
EOF
  chmod +x "$COQUI_PATH/main.py"
  echo_info "🔧 main.py criado para o serviço Coqui"
fi

if [ ! -f "$COQUI_PATH/Dockerfile" ]; then
  cat <<EOF > "$COQUI_PATH/Dockerfile"
FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir TTS flask
EXPOSE 9001
CMD ["python", "main.py"]
EOF
  echo_info "📦 Dockerfile criado para o serviço Coqui"
fi

# Whisper

echo_info "Verificando arquivos base para o serviço Whisper..."
WHISPER_PATH=./build/whisper
if [ ! -f "$WHISPER_PATH/main.py" ]; then
  cat <<EOF > "$WHISPER_PATH/main.py"
from faster_whisper import WhisperModel
from flask import Flask, request, jsonify
import tempfile
import os

app = Flask(__name__)
model_size = os.getenv("WHISPER_MODEL", "medium")
model = WhisperModel(model_size, compute_type="int8")

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if 'file' not in request.files:
        return {"error": "No file provided"}, 400

    audio_file = request.files['file']
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        audio_file.save(tmp.name)
        segments, _ = model.transcribe(tmp.name)
        text = " ".join([seg.text for seg in segments])
        return jsonify({"transcription": text})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
EOF
  chmod +x "$WHISPER_PATH/main.py"
  echo_info "🔧 main.py criado para o serviço Whisper"
fi

if [ ! -f "$WHISPER_PATH/Dockerfile" ]; then
  cat <<EOF > "$WHISPER_PATH/Dockerfile"
FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir faster-whisper flask
EXPOSE 9000
CMD ["python", "main.py"]
EOF
  echo_info "📦 Dockerfile criado para o serviço Whisper"
fi

# BLIP2

echo_info "Verificando arquivos base para o serviço BLIP2..."
BLIP2_PATH=./build/blip2
if [ ! -f "$BLIP2_PATH/main.py" ]; then
  cat <<EOF > "$BLIP2_PATH/main.py"
from lavis.models import load_model_and_preprocess
from PIL import Image
from flask import Flask, request, jsonify
import torch
import os

app = Flask(__name__)
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model, vis_processors, _ = load_model_and_preprocess("blip2_t5", "pretrain_flant5xl", device=device)

@app.route("/describe", methods=["POST"])
def describe():
    if 'file' not in request.files:
        return {"error": "No file part"}, 400
    image = Image.open(request.files['file'].stream).convert("RGB")
    image_tensor = vis_processors["eval"](image).unsqueeze(0).to(device)
    output = model.generate({"image": image_tensor})
    return jsonify({"description": output[0]})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9003)
EOF
  chmod +x "$BLIP2_PATH/main.py"
  echo_info "🔧 main.py criado para o serviço BLIP2"
fi

if [ ! -f "$BLIP2_PATH/Dockerfile" ]; then
  cat <<EOF > "$BLIP2_PATH/Dockerfile"
FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir torch lavis pillow flask
EXPOSE 9003
CMD ["python", "main.py"]
EOF
  echo_info "📦 Dockerfile criado para o serviço BLIP2"
fi

# SESANE

echo_info "Verificando arquivos base para o serviço SESANE..."
SESAME_PATH=./build/sesame
if [ ! -f "$SESAME_PATH/main.py" ]; then
  cat <<EOF > "$SESAME_PATH/main.py"
print("SESANE iniciado - agente cognitivo aguardando comandos...")
EOF
  chmod +x "$SESAME_PATH/main.py"
  echo_info "🔧 main.py criado para o serviço SESANE"
fi

if [ ! -f "$SESAME_PATH/Dockerfile" ]; then
  cat <<EOF > "$SESAME_PATH/Dockerfile"
FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir requests flask
EXPOSE 8003
CMD ["python", "main.py"]
EOF
  echo_info "📦 Dockerfile criado para o serviço SESANE"
fi

# Jira

echo_info "Verificando arquivos base para o serviço Jira..."
JIRA_PATH=./build/jira
if [ ! -f "$JIRA_PATH/main.py" ]; then
  cat <<EOF > "$JIRA_PATH/main.py"
print("Jira container iniciado - Setup manual necessário via interface web.")
EOF
  chmod +x "$JIRA_PATH/main.py"
  echo_info "🔧 main.py criado para o serviço Jira"
fi

if [ ! -f "$JIRA_PATH/Dockerfile" ]; then
  cat <<EOF > "$JIRA_PATH/Dockerfile"
FROM atlassian/jira-software:latest
COPY main.py /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
EOF
  echo_info "📦 Dockerfile criado para o serviço Jira"
fi

echo_info "Verificando arquivos base para o serviço Stable Diffusion..."
SD_PATH=./build/auto1111
SD_REPO="$SD_PATH/stable-diffusion-webui-docker"

if [ ! -d "$SD_REPO" ]; then
  git clone --depth=1 https://github.com/AbdBarho/stable-diffusion-webui-docker "$SD_REPO"
  echo_info "📦 Repositório do Stable Diffusion clonado em $SD_REPO"
else
  echo_done "Repositório já clonado em $SD_REPO"
fi

# ───── Validação final: arquivos obrigatórios para build ─────────────────────
REQUIRED_DOCKERFILES=(
  "./build/venom/Dockerfile"
  "./build/jira/Dockerfile"
)

for df in "${REQUIRED_DOCKERFILES[@]}"; do
  if [ ! -f "$df" ]; then
    echo_error "❌ Dockerfile ausente: $df"
    echo_error "Execute o run.sh novamente e verifique os logs de criação de arquivos."
    read -n 1 -s -r -p "🔁 Pressione qualquer tecla para sair..."
    exit 1
  fi
done

# ───── Executando Docker Compose ────────────────────────────────────────────
echo_info "Subindo containers com Docker Compose..."
docker compose pull || echo_info "Algumas imagens são locais e não foram baixadas."
docker compose up -d --build

# ───── Exibindo status e endpoints ──────────────────────────────────────────
echo_done "Safira iniciada com sucesso! Endpoints disponíveis:"
echo -e "${BOLD}🔧 Orquestrador:${RESET}        http://localhost:5678"
echo -e "${BOLD}📲 WhatsApp:${RESET}            http://localhost:3000"
echo -e "${BOLD}🧠 LLM Ollama:${RESET}          http://localhost:11434"
echo -e "${BOLD}🎙️ STT Whisper:${RESET}        http://localhost:9000"
echo -e "${BOLD}🗣️ TTS Coqui:${RESET}           http://localhost:9001"
echo -e "${BOLD}📊 Grafana:${RESET}             http://localhost:3001"
echo -e "${BOLD}🛠️ Jenkins:${RESET}            http://localhost:8083"
echo -e "${BOLD}🧾 Jira:${RESET}               http://localhost:8082"
echo -e "${BOLD}🧠 SESANE:${RESET}             http://localhost:8003"
echo -e "${BOLD}🎨 Stable Diffusion:${RESET}   http://localhost:7860"
echo -e "${BOLD}📦 MinIO:${RESET}              http://localhost:9002"
echo -e "${BOLD}🔄 Traefik:${RESET}            http://localhost:8080"
echo -e "${BOLD}🧱 NGINX:${RESET}              http://localhost:8081"

# ───── Logs em tempo real ───────────────────────────────────────────────────
echo_info "Logs em tempo real dos serviços (Ctrl+C para sair)"
docker compose logs -f --tail=20
# ───── Espera por tecla antes de fechar ──────────────────────────────────
echo "\n🚀 Pressione Enter para sair..."
read