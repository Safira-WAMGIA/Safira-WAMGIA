FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    gcc g++ build-essential python3-dev \
    git ffmpeg libglib2.0-0 libsm6 libxext6 libxrender-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --upgrade pip && \
    pip install --no-cache-dir open3d==0.14.1

RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    flask pillow

RUN git clone https://github.com/salesforce/LAVIS.git /lavis && \
    sed -i '/open3d==0.13.0/d' /lavis/setup.py && \
    sed -i '/open3d==0.13.0/d' /lavis/pyproject.toml && \
    sed -i '/open3d==0.13.0/d' /lavis/requirements.txt && \
    pip install --no-cache-dir /lavis

COPY main.py .

EXPOSE 9003
CMD ["python", "main.py"]
