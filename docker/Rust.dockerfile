# Rust 开发环境 Dockerfile
FROM rust:1.75

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    libwebkit2gtk-4.0-dev \
    libxdo-dev \
    libxrandr-dev \
    libxss-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust 工具
RUN cargo install cargo-watch cargo-edit cargo-audit cargo-outdated

# 添加 WebAssembly 目标
RUN rustup target add wasm32-unknown-unknown

# 设置工作目录
WORKDIR /workspace

# 复制 Cargo 配置
COPY rust-core/Cargo.toml rust-core/Cargo.lock* ./

# 预下载依赖
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build && rm -rf src

# 暴露端口
EXPOSE 8080

CMD ["cargo", "run"]