FROM ghcr.io/coqui-ai/tts-cpu:latest 

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

ENV MODEL_NAME=tts_models/pt/cv/vits \
    PORT=5000 \
    USE_CUDA=false

EXPOSE 5000
ENTRYPOINT ["python", "main.py"]
