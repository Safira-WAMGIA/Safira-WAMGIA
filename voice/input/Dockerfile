FROM python:3.10-slim


RUN apt-get update -y && \
    apt-get install -y --no-install-recommends ffmpeg curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG TORCH_VER=2.2.2   # última estável hoje
RUN pip install --no-cache-dir \
        torch==${TORCH_VER}+cpu \
        torchaudio==${TORCH_VER}+cpu \
        --extra-index-url https://download.pytorch.org/whl/cpu


COPY requirements.txt .
# requirements.txt deve conter:
# fastapi
# uvicorn[standard]
# faster-whisper==1.1.1
RUN pip install --no-cache-dir -r requirements.txt


RUN python - <<'PY'
from faster_whisper import WhisperModel
WhisperModel("small", compute_type="int8")     # "small" ≈ 500 MB, muda se quiser
PY

COPY main.py .

EXPOSE 9000
HEALTHCHECK CMD curl -sf http://localhost:9000/healthz || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "9000"]
