FROM python:3.12-slim

# —— dependências do sistema ——
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg sox && \
    rm -rf /var/lib/apt/lists/*

# —— prepara ambiente —— 
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# —— copia fonte —— 
COPY main.py .

# —— porta HTTP —— 
EXPOSE 9002

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:9002/healthz || exit 1

CMD ["python", "main.py"]
