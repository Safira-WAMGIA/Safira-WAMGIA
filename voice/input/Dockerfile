FROM python:3.12-slim

RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# baixa pesos já no build p/ evitar download em runtime
RUN python - <<'PY'
from faster_whisper import WhisperModel
WhisperModel("medium", compute_type="int8")   # troca p/ "small" se preferir
PY

COPY main.py .
EXPOSE 9000
HEALTHCHECK CMD curl -f http://localhost:9000/healthz || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "9000"]
