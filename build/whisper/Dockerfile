FROM python:3.10-slim

# Instala ffmpeg e dependências básicas
RUN apt-get update && apt-get install -y \
    ffmpeg \
 && rm -rf /var/lib/apt/lists/*

# Define diretório de trabalho
WORKDIR /app

# Copia os arquivos do serviço
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Define variável de ambiente com modelo default (pode ser sobrescrita no docker-compose)
ENV WHISPER_MODEL=medium

# Healthcheck opcional
HEALTHCHECK CMD curl -f http://localhost:9000/ || exit 1

# Expõe a porta do Flask
EXPOSE 9000

# Comando padrão
CMD ["python", "main.py"]
