FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*     && pip install --no-cache-dir faster-whisper flask
EXPOSE 9000
CMD ["python", "main.py"]
