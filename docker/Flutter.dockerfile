# Flutter 开发环境 Dockerfile
FROM ubuntu:24.04

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    xz-utils \
    zip \
    libgconf-2-4 \
    gdb \
    libstdc++6 \
    libglu1-mesa \
    fonts-droid-fallback \
    lib32stdc++6 \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# 安装 Flutter
ENV FLUTTER_HOME="/opt/flutter"
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME
RUN flutter doctor
RUN flutter config --enable-web --no-analytics
RUN flutter precache

# 设置工作目录
WORKDIR /workspace

# 暴露端口
EXPOSE 8081

CMD ["flutter", "run", "-d", "web-server", "--web-port", "8081", "--web-hostname", "0.0.0.0"]