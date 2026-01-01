# 开发工具容器 Dockerfile
FROM ubuntu:24.04

# 安装基础工具
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    jq \
    tree \
    htop \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    gnupg \
    software-properties-common \
    apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# 安装 Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce-cli && rm -rf /var/lib/apt/lists/*

# 安装 GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
RUN apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# 安装现代化工具
RUN apt-get update && apt-get install -y \
    bat \
    exa \
    fd-find \
    ripgrep \
    fzf \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /workspace

CMD ["bash"]