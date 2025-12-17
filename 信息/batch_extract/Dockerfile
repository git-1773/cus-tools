FROM python:3.10-slim

# 系统依赖
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖
RUN pip install --no-cache-dir \
    numpy \
    opencv-python \
    librosa \
    soundfile \
    pandas \
    scikit-learn


WORKDIR /app
