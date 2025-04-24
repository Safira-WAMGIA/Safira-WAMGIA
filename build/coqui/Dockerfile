FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir TTS flask
EXPOSE 9001
CMD ["python", "main.py"]
