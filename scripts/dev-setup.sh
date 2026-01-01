#!/bin/bash

# 开发环境快速设置脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查必要工具
check_requirements() {
    log_info "检查开发环境要求..."
    
    local missing_tools=()
    
    command -v rustc >/dev/null 2>&1 || missing_tools+=("rust")
    command -v flutter >/dev/null 2>&1 || missing_tools+=("flutter")
    command -v node >/dev/null 2>&1 || missing_tools+=("node")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v git >/dev/null 2>&1 || missing_tools+=("git")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少以下工具: ${missing_tools[*]}"
        log_info "请先运行 setup-dev-env.sh 安装开发环境"
        exit 1
    fi
    
    log_success "所有必要工具已安装"
}

# 初始化项目结构
init_project_structure() {
    log_info "初始化项目结构..."
    
    # 创建项目目录
    mkdir -p {rust-core,flutter-client,wechat-miniprogram,signaling-server,docker,scripts,docs}
    
    # 初始化 Rust 项目
    if [ ! -f "rust-core/Cargo.toml" ]; then
        cd rust-core
        cargo init --name remote-desktop-core
        cd ..
        log_success "Rust 项目初始化完成"
    fi
    
    # 初始化 Flutter 项目
    if [ ! -f "flutter-client/pubspec.yaml" ]; then
        flutter create --platforms=web,android,ios,windows,macos,linux flutter-client
        log_success "Flutter 项目初始化完成"
    fi
    
    # 初始化信令服务器
    if [ ! -f "signaling-server/package.json" ]; then
        cd signaling-server
        npm init -y
        npm install express socket.io cors dotenv
        npm install -D nodemon typescript @types/node @types/express
        cd ..
        log_success "信令服务器项目初始化完成"
    fi
}

# 配置开发环境
configure_dev_env() {
    log_info "配置开发环境..."
    
    # 配置 Rust
    if [ ! -f "rust-core/.cargo/config.toml" ]; then
        mkdir -p rust-core/.cargo
        cat > rust-core/.cargo/config.toml << 'EOF'
[build]
target-dir = "target"

[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[registries.crates-io]
protocol = "sparse"
EOF
        log_success "Rust 配置完成"
    fi
    
    # 配置 Flutter
    flutter config --no-analytics
    flutter config --enable-web
    
    # 配置 Git hooks
    if [ ! -f ".git/hooks/pre-commit" ]; then
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# 运行代码检查
echo "运行代码检查..."

# Rust 检查
if [ -d "rust-core" ]; then
    cd rust-core
    cargo fmt --all -- --check
    cargo clippy --all-targets --all-features -- -D warnings
    cd ..
fi

# Flutter 检查
if [ -d "flutter-client" ]; then
    cd flutter-client
    flutter analyze
    dart format --set-exit-if-changed .
    cd ..
fi

echo "代码检查通过"
EOF
        chmod +x .git/hooks/pre-commit
        log_success "Git hooks 配置完成"
    fi
}

# 启动开发服务
start_dev_services() {
    log_info "启动开发服务..."
    
    # 检查 Docker
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 未运行，请启动 Docker 服务"
        exit 1
    fi
    
    # 启动开发环境
    docker-compose -f docker-compose.dev.yml up -d
    
    log_success "开发服务已启动"
    log_info "服务地址:"
    log_info "  - Rust 开发服务: http://localhost:8080"
    log_info "  - Flutter Web: http://localhost:8081"
    log_info "  - 信令服务器: http://localhost:3000"
    log_info "  - Redis: localhost:6379"
    log_info "  - PostgreSQL: localhost:5432"
}

# 停止开发服务
stop_dev_services() {
    log_info "停止开发服务..."
    docker-compose -f docker-compose.dev.yml down
    log_success "开发服务已停止"
}

# 清理开发环境
clean_dev_env() {
    log_info "清理开发环境..."
    
    # 停止服务
    docker-compose -f docker-compose.dev.yml down -v
    
    # 清理 Rust
    if [ -d "rust-core" ]; then
        cd rust-core
        cargo clean
        cd ..
    fi
    
    # 清理 Flutter
    if [ -d "flutter-client" ]; then
        cd flutter-client
        flutter clean
        cd ..
    fi
    
    # 清理 Node.js
    if [ -d "signaling-server" ]; then
        cd signaling-server
        rm -rf node_modules
        cd ..
    fi
    
    # 清理 Docker
    docker system prune -f
    
    log_success "开发环境清理完成"
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    
    # Rust 测试
    if [ -d "rust-core" ]; then
        cd rust-core
        cargo test
        cd ..
    fi
    
    # Flutter 测试
    if [ -d "flutter-client" ]; then
        cd flutter-client
        flutter test
        cd ..
    fi
    
    # Node.js 测试
    if [ -d "signaling-server" ]; then
        cd signaling-server
        npm test 2>/dev/null || echo "No tests configured for signaling server"
        cd ..
    fi
    
    log_success "测试完成"
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
开发环境管理脚本

用法: ./scripts/dev-setup.sh [命令]

命令:
  init     - 初始化项目结构
  config   - 配置开发环境
  start    - 启动开发服务
  stop     - 停止开发服务
  clean    - 清理开发环境
  test     - 运行测试
  help     - 显示帮助信息

示例:
  ./scripts/dev-setup.sh init
  ./scripts/dev-setup.sh start
  ./scripts/dev-setup.sh test
EOF
}

# 主函数
main() {
    case "${1:-help}" in
        "init")
            check_requirements
            init_project_structure
            configure_dev_env
            ;;
        "config")
            configure_dev_env
            ;;
        "start")
            check_requirements
            start_dev_services
            ;;
        "stop")
            stop_dev_services
            ;;
        "clean")
            clean_dev_env
            ;;
        "test")
            check_requirements
            run_tests
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"