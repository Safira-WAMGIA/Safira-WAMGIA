FROM ghcr.io/coqui-ai/tts-cpu:latest 

WORKDIR /app

# 1. dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 2. application code
COPY main.py .

# 3. ambiente e exposição
ENV MODEL_NAME=tts_models/pt/cv/vits \
    PORT=5000 \
    USE_CUDA=false

EXPOSE 5000
ENTRYPOINT ["python", "main.py"]
