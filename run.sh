#!/bin/bash
# Este script configura e inicia o ambiente Safira AI/ML e automação com Docker Compose.

# ───── Configurações do Shell ──────────────────────────────────────────────
set -Eeuo pipefail
# shopt -s inherit_errexit 2>/dev/null || true
# Trap para exibir uma mensagem de erro e aguardar ao encontrar qualquer erro
trap 'echo -e "\n${RED}❌ Erro durante execução. Verifique os logs acima.${RESET}"; read -n 1 -s -r -p "\n${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"' ERR

# ───── Cores ────────────────────────────────────────────────────────────────
BOLD="\e[1m"; GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; RESET="\e[0m"
echo_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
echo_done() { echo -e "${GREEN}[OK]${RESET} $1"; }
echo_warn() { echo -e "${YELLOW}[AVISO]${RESET} $1"; }
echo_error() { echo -e "${RED}[ERRO]${RESET} $1"; }

# ───── Variáveis ──────────────────────────────────────────────────────────
DOCKER_COMPOSE_FILE="docker-compose.yaml"
ENV_FILE=".env"
ENV_EXAMPLE_FILE=".env.example"
SD_REPO_URL="https://github.com/AbdBarho/stable-diffusion-webui-docker"
SD_CLONE_PATH="./build/auto1111/stable-diffusion-webui-docker"


# ───── Flags Default ───────────────────────────────────────────────────────
BUILD_FLAG=""
RESET_FLAG=false
STATUS_FLAG=false
NON_INTERACTIVE=false
ONLY=""

# ───── Parsing de Flags de Linha de Comando ──────────────────────────────
echo_info "Analisando argumentos: $@"
for arg in "$@"; do
  case $arg in
    --build) BUILD_FLAG="--build"; echo_info "Flag --build ativo.";;
    --no-build) BUILD_FLAG=""; echo_info "Flag --no-build ativo.";;
    --reset) RESET_FLAG=true; echo_info "Flag --reset ativo.";;
    --status) STATUS_FLAG=true; echo_info "Flag --status ativo.";;
    --non-interactive) NON_INTERACTIVE=true; echo_info "Flag --non-interactive ativo.";;
    *)
      echo_warn "Argumento '$arg' não reconhecido. Ignorando."
      ;;
  esac
done

# ───── Execução Baseada em Flags Especiais ──────────────────────────────────
if [ "$RESET_FLAG" = true ]; then
  echo_info "Resetando ambiente Safira..."
  docker compose -f $DOCKER_COMPOSE_FILE down --volumes --remove-orphans || echo_warn "Comando 'docker compose down' falhou ou o ambiente já estava limpo."
  echo_done "Ambiente limpo."
  exit 0
fi

if [ "$STATUS_FLAG" = true ]; then
  echo_info "Exibindo status dos containers:"
  docker compose -f $DOCKER_COMPOSE_FILE ps
  exit 0
fi

# ───── Validando pré-requisitos ─────────────────────────────────────────────
echo_info "Verificando dependências..."
if [ -z "$BASH" ]; then
  echo_error "Este script foi projetado para rodar em Bash."
  echo_error "Execute-o via './run.sh' após dar 'chmod +x' ou explicitamente com 'bash ./run.sh'."
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo_error "Docker não está instalado ou não está no PATH."; exit 1; }
command -v docker compose >/dev/null 2>&1 || { echo_error "Docker Compose (V2) não encontrado no PATH. Certifique-se de que a integração WSL do Docker Desktop está ativa para esta distribuição."; exit 1; }
command -v git >/dev/null 2>&1 || { echo_error "Git não está instalado ou não está no PATH."; exit 1; }
echo_done "Dependências verificadas."

# ───── Preparando arquivo .env ──────────────────────────────────────────
echo_info "Verificando arquivo $ENV_FILE..."
if [ ! -f "$ENV_FILE" ]; then
  if [ -f "$ENV_EXAMPLE_FILE" ]; then
    echo_warn "$ENV_FILE não encontrado. Criando a partir de $ENV_EXAMPLE_FILE..."
    cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
    echo_done "$ENV_FILE gerado."
  else
    echo_error "$ENV_FILE e $ENV_EXAMPLE_FILE não encontrados."
    echo_error "Crie um arquivo $ENV_FILE vazio ou com suas configurações necessárias."
    read -n 1 -s -r -p "${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"
    exit 1
  fi
else
  echo_done "$ENV_FILE já existe."
fi

# ───── Preenchendo variáveis sensíveis no .env (se interativo) ──────────
echo_info "Validando variáveis sensíveis no $ENV_FILE..."

ensure_secret() {
  local var="$1"
  local default="$2"
  if ! grep -q "^${var}=" "$ENV_FILE"; then
    echo "${var}=${default}" >> "$ENV_FILE"
  fi
  local current_value=$(grep "^${var}=" "$ENV_FILE" | cut -d '=' -f2-)
  if [ -z "$current_value" ] && [ "$NON_INTERACTIVE" = false ]; then
    read -rp "🔐 Informe um valor para ${var}: " input
    sed -i "s|^${var}=.*|${var}=${input}|" "$ENV_FILE"
    echo_done "${var} definido."
  elif [ -z "$current_value" ] && [ "$NON_INTERACTIVE" = true ]; then
     echo_warn "${var} está vazio no $ENV_FILE. Ignorando (non-interactive ativo)."
  else
    echo_done "${var} já definido."
  fi
}

SECRETS_TO_CHECK=(
  N8N_BASIC_AUTH_PASSWORD
  REDIS_PASSWORD
  MINIO_ROOT_PASSWORD
  POSTGRES_PASSWORD
  GRAFANA_ADMIN_PASSWORD
  JENKINS_ADMIN_PASSWORD
  SD_API_KEY
)

for var in "${SECRETS_TO_CHECK[@]}"; do
  ensure_secret "$var" ""
done
echo_done "Validação de variáveis sensíveis completa."

echo_info "Garantindo estrutura mínima de pastas e arquivos..."

DIRS=(
  ./build/venom
  ./build/sesame
  ./build/whisper
  ./build/coqui
  ./build/jira
  ./build/blip2
  ./build/auto1111
)

for dir in "${DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo_info "📁 Criado: $dir"
  fi
done
echo_done "Estrutura de diretórios verificada/criada."

echo_info "Verificando arquivos base para o serviço Venom..."
VENOM_PATH=./build/venom
cat <<'EOF_VENOM_PKG' > "$VENOM_PATH/package.json"
{
  "name": "safira-whatsapp",
  "version": "1.0.0",
  "main": "main.js",
  "type": "module",
  "dependencies": {
    "venom-bot": "^5.1.0"
  }
}
EOF_VENOM_PKG
echo_info "📦 package.json verificado/criado para Venom"

cat <<'EOF_VENOM_MAIN' > "$VENOM_PATH/main.js"
const { create } = require('venom-bot');

create({
  session: 'safira-whatsapp-session',
  headless: true,
  disableWelcome: true,
  logQR: false,
  folderNameToken: './sessions'
}).then((client) => {
  console.log("Venom client started!");

  client.onMessage((message) => {
    console.log('Mensagem recebida:', message.body);
    if (message.body && message.isGroupMsg === false && message.type === 'chat') {
      client.sendText(message.from, 'Olá! Aqui é a Safira ✨\nRecebi sua mensagem: "' + message.body + '"');
    }
  });

  client.onStateChange((state) => {
    console.log('[Venom State] ', state);
    if (state === 'CONFLICT' || state === 'UNPAIRED' || state === 'UNLAUNCHED') {
      console.error('Venom client disconnected or needs re-pairing.');
    }
  });

}).catch((error) => {
  console.error('Erro ao iniciar Venom client: ', error);
});
EOF_VENOM_MAIN
chmod +x "$VENOM_PATH/main.js"
echo_info "🔧 main.js verificado/criado para Venom"

cat <<'EOF_VENOM_DOCKERFILE' > "$VENOM_PATH/Dockerfile"
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --production --silent --no-progress
COPY . .
EXPOSE 3000
CMD ["node", "main.js"]
EOF_VENOM_DOCKERFILE
echo_info "📦 Dockerfile verificado/criado para Venom"

echo_info "Verificando arquivos base para o serviço Coqui..."
COQUI_PATH=./build/coqui
cat <<'EOF_COQUI_MAIN' > "$COQUI_PATH/main.py"
from TTS.api import TTS
from flask import Flask, request, send_file, jsonify
import uuid
import os
import torch

app = Flask(__name__)

MODEL_NAME = os.getenv("COQUI_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")
DEVICE = os.getenv("COQUI_DEVICE", "cpu")
if DEVICE == "cuda" and not torch.cuda.is_available():
    print("CUDA não disponível, forçando DEVICE='cpu'")
    DEVICE = "cpu"
elif DEVICE == "cuda":
    print(f"CUDA disponível. Usando DEVICE='{DEVICE}'")
else:
    print(f"Usando DEVICE='{DEVICE}'")

try:
    tts = TTS(model_name=MODEL_NAME, progress_bar=False, gpu=(DEVICE == "cuda"))
    print(f"Modelo TTS '{MODEL_NAME}' carregado com sucesso em '{DEVICE}'.")
except Exception as e:
    print(f"Erro ao carregar modelo TTS '{MODEL_NAME}': {e}")
    print("Verifique se o modelo existe, se as dependências estão corretas e se o DEVICE está configurado adequadamente.")
    tts = None

@app.route("/speak", methods=["POST"])
def speak():
    if tts is None:
        return jsonify({"error": "Serviço TTS não inicializado"}), 500

    data = request.json
    text = data.get("text", "")
    speaker = data.get("speaker", None)
    language = data.get("language", None)

    if not text:
        return jsonify({"error": "Nenhum texto fornecido"}), 400

    output_path = f"/tmp/{uuid.uuid4()}.wav"
    try:
        tts.tts_to_file(text=text, file_path=output_path, speaker=speaker, language=language)

        if os.path.exists(output_path):
            response = send_file(output_path, mimetype="audio/wav")
            os.remove(output_path)
            return response
        else:
            return jsonify({"error": "Falha ao gerar arquivo de áudio."}), 500
    except Exception as e:
        print(f"Erro durante a geração do áudio: {e}")
        return jsonify({"error": f"Erro durante a geração do audio: {e}"}), 500

@app.route("/")
def status():
    if tts is None:
        return jsonify({"status": "error", "message": "Serviço TTS não inicializado."}), 500
    return jsonify({"status": "ok", "model": MODEL_NAME, "device": DEVICE})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9001)
EOF_COQUI_MAIN
chmod +x "$COQUI_PATH/main.py"
echo_info "🔧 main.py verificado/criado para Coqui"

cat <<'EOF_COQUI_DOCKERFILE' > "$COQUI_PATH/Dockerfile"
FROM python:3.10-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY main.py .

RUN pip install --no-cache-dir \
    TTS \
    flask \
    torch==2.2.2 torchvision==0.17.2 torchaudio==2.2.2 --index-url https://download.pytorch.org/whl/cpu

EXPOSE 9001
CMD ["python", "main.py"]
EOF_COQUI_DOCKERFILE
echo_info "📦 Dockerfile verificado/creado para Coqui"

echo_info "Verificando arquivos base para o serviço Whisper..."
WHISPER_PATH=./build/whisper
cat <<'EOF_WHISPER_MAIN' > "$WHISPER_PATH/main.py"
from faster_whisper import WhisperModel
from flask import Flask, request, jsonify
import tempfile
import os
import torch

app = Flask(__name__)

MODEL_SIZE = os.getenv("WHISPER_MODEL", "medium")
DEVICE = os.getenv("WHISPER_DEVICE", "cpu")
COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")

if DEVICE == "cuda" and not torch.cuda.is_available():
    print("CUDA não disponível, forçando DEVICE='cpu' e COMPUTE_TYPE='int8'")
    DEVICE = "cpu"
    COMPUTE_TYPE = "int8"
elif DEVICE == "cuda":
     print(f"CUDA disponível. Usando DEVICE='{DEVICE}' e COMPUTE_TYPE='{COMPUTE_TYPE}'")
else:
     print(f"Usando DEVICE='{DEVICE}' e COMPUTE_TYPE='{COMPUTE_TYPE}'")

try:
    model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE_TYPE)
    print(f"Modelo Whisper '{MODEL_SIZE}' carregado com sucesso em '{DEVICE}' ({COMPUTE_TYPE}).")
except Exception as e:
    print(f"Erro ao carregar modelo Whisper '{MODEL_SIZE}': {e}")
    print("Verifique o nome do modelo, as dependências (Torch com ou sem GPU) e as configurações de dispositivo/compute_type.")
    model = None

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if model is None:
         return jsonify({"error": "Serviço Whisper não inicializado"}), 500

    if 'file' not in request.files:
        return jsonify({"error": "Nenhum arquivo fornecido"}), 400

    audio_file = request.files['file']
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        audio_file.save(tmp.name)
        temp_path = tmp.name

    text = ""
    try:
        language = os.getenv("WHISPER_LANGUAGE", None)
        print(f"Transcrevendo áudio (idioma: {language})...")
        segments, info = model.transcribe(temp_path, language=language)
        print(f"Detecção de idioma: {info.language} com probabilidade {info.language_probability:.2f}")
        text = " ".join([seg.text for seg in segments]).strip()
        print(f"Transcrição concluída: \"{text[:100]}...\"")
        return jsonify({"transcription": text, "language": info.language, "language_probability": round(info.language_probability, 2)})
    except Exception as e:
        print(f"Erro durante a transcrição: {e}")
        return jsonify({"error": f"Erro durante a transcrição: {e}"}), 500
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.route("/")
def status():
     if model is None:
        return jsonify({"status": "error", "message": "Serviço Whisper não inicializado."}), 500
     return jsonify({"status": "ok", "model": MODEL_SIZE, "device": DEVICE, "compute_type": COMPUTE_TYPE})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
EOF_WHISPER_MAIN
chmod +x "$WHISPER_PATH/main.py"
echo_info "🔧 main.py verificado/criado para Whisper"

cat <<'EOF_WHISPER_DOCKERFILE' > "$WHISPER_PATH/Dockerfile"
FROM python:3.10-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY main.py .

RUN pip install --no-cache-dir \
    faster-whisper \
    flask \
    torch==2.2.2 torchvision==0.17.2 torchaudio==2.2.2 --index-url https://download.pytorch.org/whl/cpu

EXPOSE 9000
CMD ["python", "main.py"]
EOF_WHISPER_DOCKERFILE
echo_info "📦 Dockerfile verificado/criado para Whisper"

echo_info "Verificando arquivos base para o serviço BLIP2..."
BLIP2_PATH=./build/blip2
cat <<'EOF_BLIP2_MAIN' > "$BLIP2_PATH/main.py"
from lavis.models import load_model_and_preprocess
from PIL import Image
from flask import Flask, request, jsonify
import torch
import os

app = Flask(__name__)

MODEL_TYPE = os.getenv("BLIP2_MODEL_TYPE", "blip2_t5")
MODEL_NAME = os.getenv("BLIP2_MODEL_NAME", "pretrain_flant5xl")
DEVICE = os.getenv("BLIP2_DEVICE", "cpu")

if DEVICE == "cuda" and not torch.cuda.is_available():
    print("CUDA não disponível, forçando DEVICE='cpu'")
    DEVICE = "cpu"
elif DEVICE == "cuda":
     print(f"CUDA disponível. Usando DEVICE='{DEVICE}'")
else:
     print(f"Usando DEVICE='{DEVICE}'")

try:
    model, vis_processors, _ = load_model_and_preprocess(name=MODEL_TYPE, model_type=MODEL_NAME, is_eval=True, device=DEVICE)
    print(f"Modelo BLIP2 '{MODEL_TYPE}/{MODEL_NAME}' carregado com sucesso em '{DEVICE}'.")
except Exception as e:
    print(f"Erro ao carregar modelo BLIP2 '{MODEL_TYPE}/{MODEL_NAME}': {e}")
    print("Verifique o nome do modelo, as dependências (Torch com ou sem GPU) e as configurações de dispositivo.")
    model = None
    vis_processors = None

@app.route("/describe", methods=["POST"])
def describe():
    if model is None or vis_processors is None:
        return jsonify({"error": "Serviço BLIP2 não inicializado"}), 500

    if 'file' not in request.files:
        return jsonify({"error": "Nenhum arquivo fornecido"}), 400

    try:
        image = Image.open(request.files['file'].stream).convert("RGB")
        image_tensor = vis_processors["eval"](image).unsqueeze(0).to(DEVICE)

        output = model.generate({"image": image_tensor})

        if output:
            description = output[0]
            print(f"Descrição gerada: \"{description}\"")
            return jsonify({"description": description})
        else:
            return jsonify({"error": "Falha ao gerar descrição."}), 500

    except Exception as e:
        print(f"Erro durante o processamento da imagem/descrição: {e}")
        return jsonify({"error": f"Erro durante o processamento: {e}"}), 500

@app.route("/")
def status():
     if model is None:
        return jsonify({"status": "error", "message": "Serviço BLIP2 não inicializado."}), 500
     return jsonify({"status": "ok", "model_type": MODEL_TYPE, "model_name": MODEL_NAME, "device": DEVICE})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9003)
EOF_BLIP2_MAIN
chmod +x "$BLIP2_PATH/main.py"
echo_info "🔧 main.py verificado/criado para BLIP2"

cat <<'EOF_BLIP2_DOCKERFILE' > "$BLIP2_PATH/Dockerfile"
FROM python:3.10-slim

WORKDIR /app
COPY main.py .

RUN pip install --no-cache-dir \
    salesforce-lavis \
    flask \
    Pillow \
    transformers \
    torch==2.2.2 torchvision==0.17.2 torchaudio==2.2.2 --index-url https://download.pytorch.org/whl/cpu

EXPOSE 9003
CMD ["python", "main.py"]
EOF_BLIP2_DOCKERFILE
echo_info "📦 Dockerfile verificado/criado para BLIP2"

echo_info "Verificando arquivos base para o serviço SESANE..."
SESAME_PATH=./build/sesame
cat <<'EOF_SESAME_MAIN' > "$SESAME_PATH/main.py"
from flask import Flask, request, jsonify
import os
import requests
import json

app = Flask(__name__)

@app.route("/")
def hello_sesame():
    return "SESANE iniciado - agente cognitivo base aguardando comandos POST em /process."

@app.route("/process", methods=["POST"])
def process_command():
    data = request.json
    command = data.get("command", "")
    params = data.get("params", {})
    print(f"Comando recebido: {command}, Params: {params}")

    if not command:
        return jsonify({"status": "error", "message": "Nenhum comando fornecido"}), 400

    result = None
    error = None

    try:
        if command == "ask_llm":
            prompt = params.get("prompt", "Olá!")
            model_name = params.get("model", os.getenv("OLLAMA_DEFAULT_MODEL", "llama2"))

            ollama_host = os.getenv("OLLAMA_HOST", "llm-ollama")
            ollama_port = os.getenv("OLLAMA_PORT", "11434")
            ollama_url = f"http://{ollama_host}:{ollama_port}/api/generate"

            ollama_payload = {
                "model": model_name,
                "prompt": prompt,
                "stream": False
            }
            print(f"Chamando LLM: {ollama_url} com modelo '{model_name}' e prompt \"{prompt[:50]}...\"")
            response = requests.post(ollama_url, json=ollama_payload)
            response.raise_for_status()
            ollama_response = response.json()
            result = ollama_response.get("response", "Nenhuma resposta do LLM.")
            print("Resposta do LLM recebida.")

        elif command == "transcribe_audio":
            audio_url = params.get("audio_url")

            if not audio_url:
                return jsonify({"status": "error", "message": "URL de áudio não fornecida para transcrição"}), 400

            whisper_host = os.getenv("WHISPER_HOST", "whisper")
            whisper_port = os.getenv("WHISPER_PORT", "9000")
            whisper_url = f"http://{whisper_host}:{whisper_port}/transcribe"

            try:
                 print(f"Baixando áudio de: {audio_url}")
                 audio_response = requests.get(audio_url, stream=True)
                 audio_response.raise_for_status()
                 filename = 'audio.wav'
                 if 'content-disposition' in audio_response.headers:
                    import re
                    fname = re.findall('filename="(.+)"', audio_response.headers['content-disposition'])
                    if fname:
                        filename = fname[0]
                 elif audio_url.split('/')[-1]:
                     filename = audio_url.split('/')[-1]

                 files = {'file': (filename, audio_response.raw, audio_response.headers.get('Content-Type', 'application/octet-stream'))}

                 print(f"Enviando áudio para transcrição em: {whisper_url}")
                 transcribe_response = requests.post(whisper_url, files=files)
                 transcribe_response.raise_for_status()
                 transcription_data = transcribe_response.json()
                 result = transcription_data.get("transcription", "Falha na transcrição.")
                 print(f"Transcrição recebida: \"{result[:100]}...\"")

            except requests.exceptions.RequestException as e:
                 error = f"Erro ao processar áudio ou chamar Whisper: {e}"
                 print(error)
                 return jsonify({"status": "error", "message": error}), 500

        elif command == "ping":
            result = "pong"

        else:
            error = f"Comando '{command}' não reconhecido."
            print(error)
            return jsonify({"status": "error", "message": error}), 400

        return jsonify({"status": "success", "result": result})

    except requests.exceptions.RequestException as e:
        error = f"Erro ao chamar serviço externo: {e}"
        print(error)
        return jsonify({"status": "error", "message": error}), 500
    except Exception as e:
        error = f"Erro interno no agente SESANE: {e}"
        print(error)
        return jsonify({"status": "error", "message": error}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8003)
EOF_SESAME_MAIN
chmod +x "$SESAME_PATH/main.py"
echo_info "🔧 main.py verificado/criado para SESANE"

cat <<'EOF_SESAME_DOCKERFILE' > "$SESAME_PATH/Dockerfile"
FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir requests flask
EXPOSE 8003
CMD ["python", "main.py"]
EOF_SESAME_DOCKERFILE
echo_info "📦 Dockerfile verificado/criado para SESANE"

echo_info "Verificando arquivos base para o serviço Jira..."
JIRA_PATH=./build/jira
cat <<'EOF_JIRA_MAIN' > "$JIRA_PATH/main.py"
echo "Este arquivo é apenas um placeholder para o contexto de build do Jira."
EOF_JIRA_MAIN

cat <<'EOF_JIRA_DOCKERFILE' > "$JIRA_PATH/Dockerfile"
FROM atlassian/jira-software:latest
EOF_JIRA_DOCKERFILE
echo_info "📦 Dockerfile verificado/criado para Jira"

echo_info "Verificando repositório do Stable Diffusion em $SD_CLONE_PATH..."

if [ ! -d "$SD_CLONE_PATH" ]; then
  echo_info "Diretório não encontrado. Clonando repositório de $SD_REPO_URL em $SD_CLONE_PATH..."
  git clone --depth=1 "$SD_REPO_URL" "$SD_CLONE_PATH"
  if [ $? -ne 0 ]; then
    echo_error "❌ Falha ao clonar repositório do Stable Diffusion de $SD_REPO_URL."
    echo_error "Verifique sua conexão com a internet, permissões e se o URL do repositório está correto."
  else
    echo_done "📦 Repositório do Stable Diffusion clonado com sucesso."
  fi
else
  if [ -d "$SD_CLONE_PATH/.git" ]; then
    echo_done "Repositório do Stable Diffusion já clonado em $SD_CLONE_PATH."
  else
    echo_error "❌ Diretório $SD_CLONE_PATH existe, mas NÃO é um repositório Git válido."
    echo_error "Não é seguro clonar ou prosseguir. Por favor, remova a pasta manualmente e execute o script novamente."
    read -n 1 -s -r -p "${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"
    exit 1
  fi
fi

if [ -f "$SD_CLONE_PATH/Dockerfile" ]; then
  echo_info "Removendo Dockerfile temporário na raiz do repositório clonado ($SD_CLONE_PATH/Dockerfile)."
  rm "$SD_CLONE_PATH/Dockerfile" || echo_warn "Falha ao remover Dockerfile temporário. Prosseguindo..."
fi
echo_done "Verificação de arquivos base para Stable Diffusion completa."

echo_info "Verificando se Dockerfiles para build existem..."
REQUIRED_DOCKERFILES=(
  "./build/venom/Dockerfile"
  "./build/sesame/Dockerfile"
  "./build/whisper/Dockerfile"
  "./build/coqui/Dockerfile"
  "./build/jira/Dockerfile"
  "./build/blip2/Dockerfile"
)

for df in "${REQUIRED_DOCKERFILES[@]}"; do
  if [ ! -f "$df" ]; then
    echo_error "❌ Dockerfile ausente após a preparação do script: $df"
    echo_error "Algo deu errado na criação de arquivos. Verifique os logs acima."
    read -n 1 -s -r -p "${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"
    exit 1
  fi
done
echo_done "Verificação de Dockerfiles para build completa."

echo_info "Validando a sintaxe do arquivo Docker Compose ($DOCKER_COMPOSE_FILE)..."
VALIDATION_OUTPUT=$(docker compose -f "$DOCKER_COMPOSE_FILE" config --quiet 2>&1)
if [ $? -ne 0 ]; then
  echo_error "❌ Falha na validação da sintaxe do arquivo Docker Compose ($DOCKER_COMPOSE_FILE)."
  echo_error "Mensagem de erro do Docker Compose:"
  echo -e "${RED}$VALIDATION_OUTPUT${RESET}"
  echo_error "Verifique a sintaxe e a indentação YAML neste arquivo."
  echo_error "Use um validador online como https://yamlvalidator.com/ para ajudar."
  read -n 1 -s -r -p "${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"
  exit 1
fi
echo_done "Validação do arquivo Docker Compose bem-sucedida."

if [ -n "$BUILD_FLAG" ]; then
  echo_info "Construindo imagens Docker com Docker Compose..."
  docker compose -f "$DOCKER_COMPOSE_FILE" build $ONLY
  BUILD_EXIT_CODE=$?
  if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo_error "❌ Falha ao construir imagens Docker (código de saída $BUILD_EXIT_CODE)."
    echo_error "Verifique os logs de build acima para detalhes do erro."
    read -n 1 -s -r -p "${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"
    exit $BUILD_EXIT_CODE
  fi
  echo_done "Construção de imagens Docker completa."
else
    echo_info "Flag --build não ativo. Puxando imagens e usando locais existentes..."
    docker compose -f "$DOCKER_COMPOSE_FILE" pull $ONLY || echo_warn "Falha ao puxar algumas imagens. O Docker Compose tentará usar imagens locais ou construídas."
fi

echo_info "Iniciando containers com Docker Compose..."
docker compose -f "$DOCKER_COMPOSE_FILE" up -d --wait --remove-orphans $BUILD_FLAG $ONLY
UP_EXIT_CODE=$?

if [ $UP_EXIT_CODE -ne 0 ]; then
  echo_error "❌ Falha ao iniciar containers (código de saída $UP_EXIT_CODE)."
  echo_error "Verifique os logs de runtime dos containers para diagnosticar o problema."
  echo_info "Exibindo logs recentes dos containers:"
  docker compose -f "$DOCKER_COMPOSE_FILE" logs --tail 50
  read -n 1 -s -r -p "${CYAN}🔁 Pressione qualquer tecla para sair...${RESET}"
  exit $UP_EXIT_CODE
else
  echo_done "Containers iniciados com sucesso!"
fi

echo_info "Status dos containers Safira:"
docker compose -f "$DOCKER_COMPOSE_FILE" ps

echo -e "\n${BOLD}🚀 Ambiente Safira iniciado! Endpoints disponíveis:${RESET}"
echo -e "${BOLD}🔧 Orquestrador (n8n):${RESET}        http://localhost:5678"
echo -e "${BOLD}📲 WhatsApp (Venom):${RESET}          http://localhost:3000"
echo -e "${BOLD}🧠 LLM Ollama:${RESET}                http://localhost:11434"
echo -e "${BOLD}🎙️ STT Whisper:${RESET}              http://localhost:9000"
echo -e "${BOLD}🗣️ TTS Coqui:${RESET}                 http://localhost:9001"
echo -e "${BOLD}📊 Grafana:${RESET}                   http://localhost:3001"
echo -e "${BOLD}🛠️ Jenkins:${RESET}                  http://localhost:8083"
echo -e "${BOLD}🧾 Jira:${RESET}                     http://localhost:8082"
echo -e "${BOLD}🧠 SESANE:${RESET}                   http://localhost:8003"
echo -e "${BOLD}🎨 Stable Diffusion:${RESET}         http://localhost:7860"
echo -e "${BOLD}📦 MinIO:${RESET}                    http://localhost:9002"
echo -e "${BOLD}🔄 Traefik:${RESET}                  http://localhost:8080"
echo -e "${BOLD}🧱 NGINX:${RESET}                   http://localhost:8081"
echo -e "${BOLD}💾 PostgreSQL:${RESET}               localhost:5432"
echo -e "${BOLD}🚄 Redis:${RESET}                    localhost:6379"
echo -e "${BOLD}📈 Prometheus:${RESET}               http://localhost:9090"

echo "\n${GREEN}✅ Script run.sh concluído.${RESET}"