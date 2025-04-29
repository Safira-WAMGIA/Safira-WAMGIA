FROM python:3.10-slim-bullseye

# deps nativos
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg libsndfile1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 9000
HEALTHCHECK CMD curl -f http://localhost:9000/healthz || exit 1
CMD ["python", "main.py"]
