#!/bin/bash

# 工一远程客户端开发环境一键部署脚本
# 适用于 Ubuntu 24.04 LTS
# 作者: Remote Desktop Team
# 版本: 1.0.0

set -e  # 遇到错误立即退出

# 全局变量
IS_SERVER=false
IS_SSH=false
IS_ROOT=false
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 辅助函数：根据用户类型执行命令
run_as_admin() {
    if [[ $IS_ROOT == true ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到您正在使用 root 用户运行此脚本"
        log_warning "使用 root 用户可能存在安全风险，建议使用普通用户"
        
        # 设置 root 用户标志
        IS_ROOT=true
        log_warning "将以 root 用户身份继续安装..."
    else
        IS_ROOT=false
    fi
}

# 检查系统版本和类型
check_system() {
    log_info "检查系统版本和类型..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "此脚本仅支持 Ubuntu 系统"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        log_warning "此脚本针对 Ubuntu 24.04 优化，当前版本: $VERSION_ID"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 检测是否为 Server 版本
    if [[ "$VARIANT_ID" == "server" ]] || [[ "$NAME" == *"Server"* ]] || ! command -v Xorg &> /dev/null; then
        IS_SERVER=true
        log_info "检测到 Ubuntu Server 环境"
    else
        IS_SERVER=false
        log_info "检测到 Ubuntu Desktop 环境"
    fi
    
    # 检测是否通过 SSH 连接
    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        IS_SSH=true
        log_info "检测到 SSH 连接环境"
    else
        IS_SSH=false
    fi
    
    log_success "系统检查通过: Ubuntu $VERSION_ID $([ "$IS_SERVER" = true ] && echo "Server" || echo "Desktop")"
}

# 更新系统包
update_system() {
    log_info "更新系统包..."
    if [[ $IS_ROOT == true ]]; then
        apt update
        apt upgrade -y
    else
        sudo apt update
        sudo apt upgrade -y
    fi
    log_success "系统包更新完成"
}

# 安装基础依赖
install_base_dependencies() {
    log_info "安装基础依赖..."
    
    local base_packages=(
        curl
        wget
        git
        build-essential
        pkg-config
        libssl-dev
        unzip
        zip
        jq
        tree
        htop
        neofetch
        vim
        nano
        ca-certificates
        gnupg
        software-properties-common
        apt-transport-https
    )
    
    # Desktop 特定依赖
    if [[ "$IS_SERVER" = false ]]; then
        local desktop_packages=(
            libgtk-3-dev
            libayatana-appindicator3-dev
            librsvg2-dev
            libwebkit2gtk-4.0-dev
            libxdo-dev
            libxrandr-dev
            libxss-dev
            libgconf-2-4
            libxss1
            libappindicator1
            libnss3
            lsb-release
            xdg-utils
        )
        base_packages+=("${desktop_packages[@]}")
        log_info "添加 Desktop 环境依赖包"
    else
        log_info "Server 环境，跳过 GUI 相关依赖"
    fi
    
    if [[ $IS_ROOT == true ]]; then
        apt install -y "${base_packages[@]}"
    else
        sudo apt install -y "${base_packages[@]}"
    fi
    
    log_success "基础依赖安装完成"
}

# 安装 Rust
install_rust() {
    log_info "安装 Rust..."
    
    if command -v rustc &> /dev/null; then
        log_warning "Rust 已安装，版本: $(rustc --version)"
        read -p "是否重新安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # 根据用户类型选择安装方式
    if [[ $IS_ROOT == true ]]; then
        # Root 用户安装到系统目录
        log_warning "以 root 用户安装 Rust 到系统目录"
        export RUSTUP_HOME=/opt/rust
        export CARGO_HOME=/opt/rust
        mkdir -p /opt/rust
        
        # 安装 Rust
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        
        # 添加到系统 PATH
        echo 'export RUSTUP_HOME=/opt/rust' >> /etc/environment
        echo 'export CARGO_HOME=/opt/rust' >> /etc/environment
        echo 'export PATH="/opt/rust/bin:$PATH"' >> /etc/environment
        
        # 临时设置环境变量
        export PATH="/opt/rust/bin:$PATH"
        source /opt/rust/env
        
        # 设置权限
        chmod -R 755 /opt/rust
        
    else
        # 普通用户安装
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    # 添加常用工具链和组件
    rustup component add clippy rustfmt
    rustup target add wasm32-unknown-unknown
    
    # 安装常用 Cargo 工具
    cargo install cargo-watch cargo-edit cargo-audit cargo-outdated
    
    log_success "Rust 安装完成，版本: $(rustc --version)"
}

# 安装 Node.js (用于微信小程序开发)
install_nodejs() {
    log_info "安装 Node.js..."
    
    if command -v node &> /dev/null; then
        log_warning "Node.js 已安装，版本: $(node --version)"
        read -p "是否重新安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # 安装 Node.js 20.x LTS
    if [[ $IS_ROOT == true ]]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    else
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    # 配置 npm 镜像源（可选）
    npm config set registry https://registry.npmmirror.com
    
    # 安装全局工具
    if [[ $IS_ROOT == true ]]; then
        npm install -g yarn pnpm @wechat-miniprogram/cli
    else
        sudo npm install -g yarn pnpm @wechat-miniprogram/cli
    fi
    
    log_success "Node.js 安装完成，版本: $(node --version)"
    log_success "npm 版本: $(npm --version)"
}

# 安装 Flutter
install_flutter() {
    log_info "安装 Flutter..."
    
    # 根据用户类型选择安装目录
    if [[ $IS_ROOT == true ]]; then
        local flutter_dir="/opt/flutter"
        local bashrc_file="/root/.bashrc"
    else
        local flutter_dir="$HOME/development/flutter"
        local bashrc_file="$HOME/.bashrc"
    fi
    
    if [[ -d "$flutter_dir" ]]; then
        log_warning "Flutter 目录已存在"
        read -p "是否重新安装? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$flutter_dir"
        else
            return
        fi
    fi
    
    # 创建开发目录
    if [[ $IS_ROOT == true ]]; then
        mkdir -p "/opt"
        cd "/opt"
    else
        mkdir -p "$HOME/development"
        cd "$HOME/development"
    fi
    
    # 下载 Flutter
    git clone https://github.com/flutter/flutter.git -b stable
    
    # 设置权限（root 用户需要）
    if [[ $IS_ROOT == true ]]; then
        chmod -R 755 "$flutter_dir"
    fi
    
    # 添加到 PATH
    if [[ $IS_ROOT == true ]]; then
        if ! grep -q "flutter/bin" "$bashrc_file"; then
            echo 'export PATH="/opt/flutter/bin:$PATH"' >> "$bashrc_file"
        fi
        # 临时添加到当前会话的 PATH
        export PATH="/opt/flutter/bin:$PATH"
    else
        if ! grep -q "flutter/bin" "$bashrc_file"; then
            echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> "$bashrc_file"
        fi
        # 临时添加到当前会话的 PATH
        export PATH="$HOME/development/flutter/bin:$PATH"
    fi
    
    # 运行 Flutter doctor
    flutter doctor
    
    # 预下载依赖
    flutter precache
    
    log_success "Flutter 安装完成"
}

# 安装 Android SDK (用于 Flutter Android 开发)
install_android_sdk() {
    log_info "安装 Android SDK..."
    
    # 根据用户类型选择安装目录
    if [[ $IS_ROOT == true ]]; then
        local android_dir="/opt/Android"
        local bashrc_file="/root/.bashrc"
    else
        local android_dir="$HOME/Android"
        local bashrc_file="$HOME/.bashrc"
    fi
    
    if [[ -d "$android_dir/Sdk" ]]; then
        log_warning "Android SDK 已存在"
        read -p "是否跳过安装? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            rm -rf "$android_dir"
        else
            return
        fi
    fi
    
    # 创建 Android 目录
    mkdir -p "$android_dir"
    cd "$android_dir"
    
    # 下载 Android Command Line Tools
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
    unzip commandlinetools-linux-11076708_latest.zip
    rm commandlinetools-linux-11076708_latest.zip
    
    # 创建正确的目录结构
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
    
    # 设置环境变量
    if [[ $IS_ROOT == true ]]; then
        if ! grep -q "ANDROID_HOME" "$bashrc_file"; then
            cat >> "$bashrc_file" << 'EOF'

# Android SDK
export ANDROID_HOME=/opt/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
EOF
        fi
        # 临时设置环境变量
        export ANDROID_HOME=/opt/Android/Sdk
        chmod -R 755 "$android_dir"
    else
        if ! grep -q "ANDROID_HOME" "$bashrc_file"; then
            cat >> "$bashrc_file" << 'EOF'

# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
EOF
        fi
        # 临时设置环境变量
        export ANDROID_HOME=$HOME/Android/Sdk
    fi
    
    export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
    export PATH=$PATH:$ANDROID_HOME/platform-tools
    export PATH=$PATH:$ANDROID_HOME/emulator
    
    # 创建 SDK 目录
    mkdir -p "$ANDROID_HOME"
    
    # 接受许可证并安装必要组件
    yes | sdkmanager --licenses
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
    
    log_success "Android SDK 安装完成"
}

# 安装 Docker (用于 CI/CD)
install_docker() {
    log_info "安装 Docker..."
    
    if command -v docker &> /dev/null; then
        log_warning "Docker 已安装，版本: $(docker --version)"
        read -p "是否跳过安装? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            return
        fi
    fi
    
    # 添加 Docker 官方 GPG 密钥
    if [[ $IS_ROOT == true ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # 添加 Docker 仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 更新包索引并安装 Docker
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # 启动 Docker 服务
        systemctl enable docker
        systemctl start docker
    else
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # 添加 Docker 仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 更新包索引并安装 Docker
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # 将用户添加到 docker 组
        sudo usermod -aG docker $USER
        
        # 启动 Docker 服务
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    
    log_success "Docker 安装完成"
    log_warning "请重新登录以使 Docker 组权限生效"
}

# 安装 VS Code
install_vscode() {
    if [[ "$IS_SERVER" = true ]]; then
        log_info "Server 环境，安装 VS Code Server..."
        install_vscode_server
        return
    fi
    
    log_info "安装 VS Code..."
    
    if command -v code &> /dev/null; then
        log_warning "VS Code 已安装"
        read -p "是否跳过安装? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            return
        fi
    fi
    
    # 添加 Microsoft GPG 密钥和仓库
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    
    if [[ $IS_ROOT == true ]]; then
        install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        
        # 安装 VS Code
        apt update
        apt install -y code
    else
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        
        # 安装 VS Code
        sudo apt update
        sudo apt install -y code
    fi
    
    # 安装推荐扩展
    install_vscode_extensions
    
    log_success "VS Code 安装完成"
}

# 安装 VS Code Server (用于远程开发)
install_vscode_server() {
    log_info "配置 VS Code Server 环境..."
    
    # VS Code Server 通常由 VS Code Remote SSH 自动安装
    # 这里主要是确保环境配置正确
    
    # 创建 VS Code Server 配置目录
    mkdir -p ~/.vscode-server/bin
    
    # 安装 code-server (可选的独立版本)
    read -p "是否安装 code-server (独立的 VS Code Server)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        curl -fsSL https://code-server.dev/install.sh | sh
        
        # 创建配置文件
        mkdir -p ~/.config/code-server
        cat > ~/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: your-secure-password-here
cert: false
EOF
        
        log_info "code-server 已安装，配置文件位于 ~/.config/code-server/config.yaml"
        log_warning "请修改配置文件中的密码！"
        
        # 创建 systemd 服务
        sudo tee /etc/systemd/system/code-server@.service > /dev/null << 'EOF'
[Unit]
Description=code-server
After=network.target

[Service]
Type=exec
ExecStart=/usr/bin/code-server
Restart=always
User=%i

[Install]
WantedBy=multi-user.target
EOF
        
        log_info "可以使用以下命令启动 code-server:"
        log_info "sudo systemctl enable --now code-server@$USER"
    fi
    
    log_success "VS Code Server 环境配置完成"
}

# 安装 VS Code 扩展
install_vscode_extensions() {
    log_info "安装 VS Code 扩展..."
    
    local extensions=(
        "rust-lang.rust-analyzer"
        "Dart-Code.flutter"
        "Dart-Code.dart-code"
        "ms-vscode.vscode-typescript-next"
        "bradlc.vscode-tailwindcss"
        "ms-vscode.vscode-json"
        "redhat.vscode-yaml"
        "ms-vscode-remote.remote-containers"
        "ms-vscode-remote.remote-ssh"
        "ms-vscode-remote.remote-ssh-edit"
        "GitHub.copilot"
        "GitHub.vscode-pull-request-github"
        "eamodio.gitlens"
        "ms-python.python"
        "ms-vscode.cmake-tools"
        "ms-vscode.cpptools"
    )
    
    if [[ "$IS_SERVER" = false ]]; then
        # Desktop 环境可以直接安装扩展
        for ext in "${extensions[@]}"; do
            code --install-extension "$ext" 2>/dev/null || log_warning "扩展 $ext 安装失败"
        done
    else
        # Server 环境，创建扩展列表供参考
        log_info "Server 环境，创建推荐扩展列表..."
        cat > ~/vscode-extensions.txt << 'EOF'
# VS Code 推荐扩展列表
# 在 VS Code Remote SSH 连接后，可以搜索并安装这些扩展

rust-lang.rust-analyzer
Dart-Code.flutter
Dart-Code.dart-code
ms-vscode.vscode-typescript-next
bradlc.vscode-tailwindcss
ms-vscode.vscode-json
redhat.vscode-yaml
ms-vscode-remote.remote-containers
GitHub.copilot
GitHub.vscode-pull-request-github
eamodio.gitlens
ms-python.python
ms-vscode.cmake-tools
ms-vscode.cpptools
EOF
        log_info "扩展列表已保存到 ~/vscode-extensions.txt"
    fi
}

# 安装微信开发者工具
install_wechat_devtools() {
    if [[ "$IS_SERVER" = true ]]; then
        log_warning "Server 环境无法安装微信开发者工具"
        log_info "建议在本地环境安装微信开发者工具，通过 Remote SSH 进行开发"
        log_info "或使用微信小程序 CLI 工具进行命令行开发"
        
        # 安装微信小程序 CLI 工具
        if command -v npm &> /dev/null; then
            log_info "安装微信小程序 CLI 工具..."
            npm install -g @wechat-miniprogram/cli
            log_success "微信小程序 CLI 工具安装完成"
        fi
        return
    fi
    
    log_info "安装微信开发者工具..."
    
    local wechat_dir="$HOME/wechat-devtools"
    
    if [[ -d "$wechat_dir" ]]; then
        log_warning "微信开发者工具目录已存在"
        read -p "是否跳过安装? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            return
        fi
    fi
    
    # 下载微信开发者工具 Linux 版本
    mkdir -p "$HOME/Downloads"
    cd "$HOME/Downloads"
    
    # 注意：这里需要手动下载，因为微信开发者工具需要从官网获取最新版本
    log_warning "微信开发者工具需要手动下载"
    log_info "请访问: https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html"
    log_info "下载 Linux 版本并解压到 $HOME/wechat-devtools"
    
    read -p "下载完成后按回车继续..." -r
    
    # 创建桌面快捷方式
    if [[ -d "$wechat_dir" ]]; then
        cat > ~/.local/share/applications/wechat-devtools.desktop << EOF
[Desktop Entry]
Name=微信开发者工具
Comment=WeChat Developer Tools
Exec=$wechat_dir/bin/wechat-devtools
Icon=$wechat_dir/package.nw/images/icon.png
Terminal=false
Type=Application
Categories=Development;
EOF
        
        log_success "微信开发者工具配置完成"
    else
        log_warning "未找到微信开发者工具目录，请手动安装"
    fi
}

# 配置 Git
configure_git() {
    log_info "配置 Git..."
    
    if git config --global user.name &> /dev/null; then
        log_warning "Git 已配置用户: $(git config --global user.name)"
        read -p "是否重新配置? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    read -p "请输入 Git 用户名: " git_username
    read -p "请输入 Git 邮箱: " git_email
    
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    
    # 配置 Git 别名
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.lg "log --oneline --graph --decorate --all"
    
    log_success "Git 配置完成"
}

# 创建项目目录结构
create_project_structure() {
    log_info "创建项目目录结构..."
    
    # 根据用户类型选择工作目录
    if [[ $IS_ROOT == true ]]; then
        local workspace_dir="/opt/workspace"
    else
        local workspace_dir="$HOME/workspace"
    fi
    
    mkdir -p "$workspace_dir"
    cd "$workspace_dir"
    
    # 创建开发目录
    mkdir -p {rust-projects,flutter-projects,miniprogram-projects,docker-configs,scripts}
    
    # 设置权限（root 用户需要）
    if [[ $IS_ROOT == true ]]; then
        chmod -R 755 "$workspace_dir"
    fi
    
    # 创建 README
    cat > README.md << 'EOF'
# 开发工作区

## 目录结构

- `rust-projects/` - Rust 项目目录
- `flutter-projects/` - Flutter 项目目录  
- `miniprogram-projects/` - 微信小程序项目目录
- `docker-configs/` - Docker 配置文件
- `scripts/` - 开发脚本

## 快速开始

### Rust 开发
```bash
cd rust-projects
cargo new my-project
cd my-project
cargo run
```

### Flutter 开发
```bash
cd flutter-projects
flutter create my_app
cd my_app
flutter run
```

### 微信小程序开发
```bash
cd miniprogram-projects
# 使用微信开发者工具创建项目
```
EOF
    
    log_success "项目目录结构创建完成: $workspace_dir"
}

# 安装额外工具
install_extra_tools() {
    log_info "安装额外开发工具..."
    
    # 安装 GitHub CLI
    if [[ $IS_ROOT == true ]]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt update
        apt install -y gh
        
        # 安装其他有用工具
        apt install -y \
            bat \
            exa \
            fd-find \
            ripgrep \
            fzf \
            zsh \
            tmux \
            httpie
    else
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh
        
        # 安装其他有用工具
        sudo apt install -y \
            bat \
            exa \
            fd-find \
            ripgrep \
            fzf \
            zsh \
            tmux \
            httpie
    fi
    
    # 安装 Oh My Zsh (可选)
    read -p "是否安装 Oh My Zsh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ $IS_ROOT == true ]]; then
            # Root 用户安装 Oh My Zsh
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            
            # 配置 zsh 插件
            if [[ -f /root/.zshrc ]]; then
                sed -i 's/plugins=(git)/plugins=(git rust flutter docker docker-compose npm yarn)/' /root/.zshrc
            fi
        else
            # 普通用户安装 Oh My Zsh
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            
            # 配置 zsh 插件
            if [[ -f ~/.zshrc ]]; then
                sed -i 's/plugins=(git)/plugins=(git rust flutter docker docker-compose npm yarn)/' ~/.zshrc
            fi
        fi
        
        log_success "Oh My Zsh 安装完成"
    fi
    
    log_success "额外工具安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    local errors=0
    
    # 检查 Rust
    if command -v rustc &> /dev/null; then
        log_success "✓ Rust: $(rustc --version)"
    else
        log_error "✗ Rust 未安装"
        ((errors++))
    fi
    
    # 检查 Flutter
    if command -v flutter &> /dev/null; then
        log_success "✓ Flutter: $(flutter --version | head -n1)"
    else
        log_error "✗ Flutter 未安装"
        ((errors++))
    fi
    
    # 检查 Node.js
    if command -v node &> /dev/null; then
        log_success "✓ Node.js: $(node --version)"
    else
        log_error "✗ Node.js 未安装"
        ((errors++))
    fi
    
    # 检查 Docker
    if command -v docker &> /dev/null; then
        log_success "✓ Docker: $(docker --version)"
    else
        log_error "✗ Docker 未安装"
        ((errors++))
    fi
    
    # 检查 VS Code
    if command -v code &> /dev/null; then
        log_success "✓ VS Code: $(code --version | head -n1)"
    else
        log_error "✗ VS Code 未安装"
        ((errors++))
    fi
    
    # 检查 Git
    if command -v git &> /dev/null; then
        log_success "✓ Git: $(git --version)"
    else
        log_error "✗ Git 未安装"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "所有工具安装验证通过！"
    else
        log_error "发现 $errors 个安装问题"
        return 1
    fi
}

# 显示安装后说明
show_post_install_info() {
    log_info "安装完成！"
    
    # 根据用户类型显示不同的路径信息
    if [[ $IS_ROOT == true ]]; then
        cat << 'EOF'

🎉 开发环境安装完成！

📋 下一步操作：

1. 重新启动终端或运行: source /root/.bashrc
2. 如果安装了 Docker，Docker 已配置完成
3. 运行 flutter doctor 检查 Flutter 环境
4. 配置 GitHub CLI: gh auth login

📁 项目目录：
   /opt/workspace/ - 主工作区
   /opt/flutter/ - Flutter SDK
   /opt/rust/ - Rust 工具链

🔧 常用命令：
   rustc --version     - 检查 Rust 版本
   flutter doctor      - 检查 Flutter 环境
   docker --version    - 检查 Docker 版本
   code .              - 在当前目录打开 VS Code

📚 文档：
   查看 DEV_ENVIRONMENT.md 了解详细使用说明

EOF
    else
        cat << 'EOF'

🎉 开发环境安装完成！

📋 下一步操作：

1. 重新启动终端或运行: source ~/.bashrc
2. 如果安装了 Docker，请重新登录以使组权限生效
3. 运行 flutter doctor 检查 Flutter 环境
4. 配置 GitHub CLI: gh auth login

📁 项目目录：
   ~/workspace/ - 主工作区
   ~/development/flutter/ - Flutter SDK

🔧 常用命令：
   rustc --version     - 检查 Rust 版本
   flutter doctor      - 检查 Flutter 环境
   docker --version    - 检查 Docker 版本
   code .              - 在当前目录打开 VS Code

📚 文档：
   查看 DEV_ENVIRONMENT.md 了解详细使用说明

EOF
    fi
}

# 主函数
main() {
    log_info "开始安装工一远程客户端开发环境..."
    log_info "目标系统: Ubuntu 24.04"
    
    check_root
    check_system
    
    # 询问用户要安装哪些组件
    echo
    log_info "请选择要安装的组件："
    log_info "检测到$([ "$IS_SERVER" = true ] && echo "Server" || echo "Desktop")环境$([ "$IS_SSH" = true ] && echo "，通过 SSH 连接" || echo "")"
    echo
    
    read -p "安装基础依赖和系统更新? (Y/n): " -n 1 -r; echo; install_base=${REPLY:-Y}
    read -p "安装 Rust? (Y/n): " -n 1 -r; echo; install_rust_flag=${REPLY:-Y}
    read -p "安装 Node.js? (Y/n): " -n 1 -r; echo; install_node_flag=${REPLY:-Y}
    read -p "安装 Flutter? (Y/n): " -n 1 -r; echo; install_flutter_flag=${REPLY:-Y}
    
    if [[ "$IS_SERVER" = false ]]; then
        read -p "安装 Android SDK? (Y/n): " -n 1 -r; echo; install_android_flag=${REPLY:-Y}
    else
        install_android_flag=N
        log_info "Server 环境，跳过 Android SDK"
    fi
    
    read -p "安装 Docker? (Y/n): " -n 1 -r; echo; install_docker_flag=${REPLY:-Y}
    read -p "安装 VS Code$([ "$IS_SERVER" = true ] && echo " Server" || echo "")? (Y/n): " -n 1 -r; echo; install_vscode_flag=${REPLY:-Y}
    
    if [[ "$IS_SERVER" = false ]]; then
        read -p "安装微信开发者工具? (y/N): " -n 1 -r; echo; install_wechat_flag=${REPLY:-N}
    else
        install_wechat_flag=N
        log_info "Server 环境，将安装微信小程序 CLI 工具"
    fi
    
    read -p "配置 Git? (Y/n): " -n 1 -r; echo; configure_git_flag=${REPLY:-Y}
    read -p "安装额外工具? (y/N): " -n 1 -r; echo; install_extra_flag=${REPLY:-N}
    
    echo
    log_info "开始安装选定的组件..."
    
    # 执行安装
    [[ $install_base =~ ^[Yy]$ ]] && { update_system; install_base_dependencies; }
    [[ $install_rust_flag =~ ^[Yy]$ ]] && install_rust
    [[ $install_node_flag =~ ^[Yy]$ ]] && install_nodejs
    [[ $install_flutter_flag =~ ^[Yy]$ ]] && install_flutter
    [[ $install_android_flag =~ ^[Yy]$ ]] && install_android_sdk
    [[ $install_docker_flag =~ ^[Yy]$ ]] && install_docker
    [[ $install_vscode_flag =~ ^[Yy]$ ]] && install_vscode
    [[ $install_wechat_flag =~ ^[Yy]$ ]] && install_wechat_devtools
    [[ $configure_git_flag =~ ^[Yy]$ ]] && configure_git
    [[ $install_extra_flag =~ ^[Yy]$ ]] && install_extra_tools
    
    create_project_structure
    verify_installation
    show_post_install_info
    
    log_success "开发环境安装完成！"
    
    # Server 环境特殊提示
    if [[ "$IS_SERVER" = true ]]; then
        echo
        log_info "🖥️  Server 环境特殊说明："
        log_info "• 使用 VS Code Remote SSH 进行远程开发"
        log_info "• Flutter 主要用于 Web 开发，移动端开发需要本地环境"
        log_info "• 微信小程序开发建议使用 CLI 工具或本地开发者工具"
        log_info "• 如安装了 code-server，可通过浏览器访问 http://服务器IP:8080"
    fi
}

# 运行主函数
main "$@"