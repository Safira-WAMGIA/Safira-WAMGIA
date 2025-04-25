FROM python:3.9-slim

# Instala ffmpeg e dependências
RUN apt-get update && apt-get install -y \
    git ffmpeg libglib2.0-0 libsm6 libxext6 libxrender-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala torch com pip direto (evita conflito de wheel com CPU/GPU)
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    flask pillow

# Instala LAVIS diretamente do repositório
RUN pip install --no-cache-dir git+https://github.com/salesforce/LAVIS.git

COPY main.py .

EXPOSE 9003
CMD ["python", "main.py"]
