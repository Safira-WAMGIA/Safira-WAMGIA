FROM python:3.9-slim

WORKDIR /app

COPY main.py .

RUN apt-get update \
 && apt-get install -y ffmpeg git \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir faster-whisper flask \
 && pip install --no-cache-dir git+https://github.com/salesforce/LAVIS.git

EXPOSE 9000

CMD ["python", "main.py"]
