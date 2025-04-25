FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    ffmpeg libsndfile1 git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir \
    TTS==0.22.0 flask

COPY main.py .

EXPOSE 9001
CMD ["python", "main.py"]
