FROM python:3.12-slim

# dependências mínimas
RUN apt-get update && apt-get install -y gcc git curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# baixa o checkpoint já no build → start mais rápido
RUN python - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download("Salesforce/blip2-opt-2.7b",
                  allow_patterns=["*.bin","*.json","*.pt"])
PY

COPY main.py .

EXPOSE 8000
HEALTHCHECK CMD curl -f http://localhost:8000/healthz || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
