FROM python:3.10-slim

# Variáveis essenciais para execução limpa
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV COQUI_TOS_AGREED 1

# Diretório da aplicação
WORKDIR /app

# Dependências necessárias para o Coqui TTS e soundfile
RUN apt-get update && apt-get install -y \
    espeak-ng \
    build-essential \
    libsndfile1-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Instalação das dependências Python
COPY requirements.txt /app/

RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copia o código da aplicação
COPY . /app
COPY audio /app/audio
# Porta da API FastAPI
EXPOSE 5000

# Inicialização do serviço
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
