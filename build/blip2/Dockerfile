FROM python:3.10-slim
WORKDIR /app
COPY main.py .
RUN pip install --no-cache-dir torch lavis pillow flask
EXPOSE 9003
CMD ["python", "main.py"]
