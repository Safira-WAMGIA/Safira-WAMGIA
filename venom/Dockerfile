FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gcc ffmpeg libsndfile1 git curl && rm -rf /var/lib/apt/lists/*
ENV APP_USER=app
RUN useradd -ms /bin/bash $APP_USER
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN chown -R $APP_USER:$APP_USER /app
USER $APP_USER
HEALTHCHECK CMD curl -f http://localhost:${HEALTH_PORT:-8000}/healthz || exit 1
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
