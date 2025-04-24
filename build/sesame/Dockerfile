FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir requests flask
EXPOSE 8003
CMD ["python", "main.py"]
