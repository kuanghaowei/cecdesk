#!/bin/bash
# 工一远控 (CEC Remote) 开发环境统一管理脚本
# 用法: ./scripts/dev.sh <命令>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IS_ROOT=false
[[ $EUID -eq 0 ]] && IS_ROOT=true

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1"; }
log_step()    { echo -e "${CYAN}[→]${NC} $1"; }

show_help() {
    cat << 'EOF'
工一远控开发环境管理脚本

用法: ./scripts/dev.sh <命令>

环境安装:
  setup           一键安装完整开发环境
  setup:rust      仅安装 Rust
  setup:flutter   仅安装 Flutter
  setup:node      仅安装 Node.js

开发命令:
  test            运行所有测试
  test:rust       运行 Rust 测试
  test:flutter    运行 Flutter 测试
  test:mini       运行小程序测试
  build           构建所有组件
  lint            代码检查
  fmt             格式化代码
  clean           清理构建产物

服务管理:
  start           启动 Docker 服务
  stop            停止服务
  logs            查看日志

其他:
  doctor          检查环境状态
  update          更新工具链
  help            显示帮助
EOF
}


# ============================================
# 环境检查
# ============================================
cmd_doctor() {
    echo -e "\n${CYAN}══════════════════════════════════════${NC}"
    echo -e "${CYAN}  工一远控开发环境检查${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}\n"
    
    local all_ok=true
    
    if command -v rustc &> /dev/null; then
        log_success "Rust: $(rustc --version | cut -d' ' -f2)"
    else
        log_error "Rust: 未安装"; all_ok=false
    fi
    
    if command -v flutter &> /dev/null; then
        log_success "Flutter: $(flutter --version 2>/dev/null | head -1 | cut -d' ' -f2)"
    else
        log_error "Flutter: 未安装"; all_ok=false
    fi
    
    if command -v node &> /dev/null; then
        log_success "Node.js: $(node --version)"
    else
        log_error "Node.js: 未安装"; all_ok=false
    fi
    
    if command -v docker &> /dev/null; then
        log_success "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        log_warning "Docker: 未安装 (可选)"
    fi
    
    if command -v git &> /dev/null; then
        log_success "Git: $(git --version | cut -d' ' -f3)"
    else
        log_error "Git: 未安装"; all_ok=false
    fi
    
    echo
    $all_ok && log_success "环境正常" || log_error "运行 './scripts/dev.sh setup' 安装缺失组件"
}

# ============================================
# 测试命令
# ============================================
cmd_test() {
    echo -e "\n${CYAN}══════════════════════════════════════${NC}"
    echo -e "${CYAN}  运行所有测试${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}\n"
    
    local start_time=$(date +%s)
    local rust_ok=true flutter_ok=true mini_ok=true
    
    log_step "[1/3] Rust 测试..."
    cd "$PROJECT_ROOT"
    cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings && cargo test --all || rust_ok=false
    $rust_ok && log_success "Rust ✓" || log_error "Rust ✗"
    
    log_step "[2/3] Flutter 测试..."
    cd "$PROJECT_ROOT/flutter-client"
    flutter analyze && flutter test || flutter_ok=false
    $flutter_ok && log_success "Flutter ✓" || log_error "Flutter ✗"
    
    log_step "[3/3] 小程序测试..."
    cd "$PROJECT_ROOT/wechat-miniprogram"
    npm test || mini_ok=false
    $mini_ok && log_success "小程序 ✓" || log_error "小程序 ✗"
    
    cd "$PROJECT_ROOT"
    echo -e "\n耗时: $(($(date +%s) - start_time))秒"
    $rust_ok && $flutter_ok && $mini_ok && log_success "全部通过！" || { log_error "部分失败"; return 1; }
}

cmd_test_rust() {
    cd "$PROJECT_ROOT"
    cargo fmt --all -- --check
    cargo clippy --all-targets -- -D warnings
    cargo test --all --verbose
}

cmd_test_flutter() {
    cd "$PROJECT_ROOT/flutter-client"
    flutter analyze
    flutter test --coverage
}

cmd_test_mini() {
    cd "$PROJECT_ROOT/wechat-miniprogram"
    npm test
}

# ============================================
# 构建命令
# ============================================
cmd_build() {
    log_step "构建 Rust..."
    cd "$PROJECT_ROOT" && cargo build --release
    
    log_step "构建 Flutter Web..."
    cd "$PROJECT_ROOT/flutter-client" && flutter build web
    
    log_success "构建完成"
}

cmd_lint() {
    cd "$PROJECT_ROOT" && cargo clippy --all-targets -- -D warnings
    cd "$PROJECT_ROOT/flutter-client" && flutter analyze
    log_success "检查完成"
}

cmd_fmt() {
    cd "$PROJECT_ROOT" && cargo fmt --all
    cd "$PROJECT_ROOT/flutter-client" && dart format .
    log_success "格式化完成"
}

cmd_clean() {
    cd "$PROJECT_ROOT" && cargo clean
    cd "$PROJECT_ROOT/flutter-client" && flutter clean
    rm -rf "$PROJECT_ROOT/wechat-miniprogram/node_modules"
    log_success "清理完成"
}

# ============================================
# 服务管理
# ============================================
cmd_start() {
    cd "$PROJECT_ROOT"
    [[ -f "docker-compose.dev.yml" ]] && docker compose -f docker-compose.dev.yml up -d && log_success "服务已启动"
}

cmd_stop() {
    cd "$PROJECT_ROOT"
    [[ -f "docker-compose.dev.yml" ]] && docker compose -f docker-compose.dev.yml down && log_success "服务已停止"
}

cmd_logs() {
    cd "$PROJECT_ROOT"
    [[ -f "docker-compose.dev.yml" ]] && docker compose -f docker-compose.dev.yml logs -f
}


# ============================================
# 环境安装
# ============================================
cmd_setup() {
    echo -e "\n${CYAN}══════════════════════════════════════${NC}"
    echo -e "${CYAN}  工一远控开发环境安装${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}\n"
    
    log_info "选择要安装的组件:"
    read -p "  安装 Rust? (Y/n): " r; r=${r:-Y}
    read -p "  安装 Flutter? (Y/n): " f; f=${f:-Y}
    read -p "  安装 Node.js? (Y/n): " n; n=${n:-Y}
    read -p "  安装 Docker? (y/N): " d; d=${d:-N}
    
    [[ $r =~ ^[Yy]$ ]] && cmd_setup_rust
    [[ $f =~ ^[Yy]$ ]] && cmd_setup_flutter
    [[ $n =~ ^[Yy]$ ]] && cmd_setup_node
    [[ $d =~ ^[Yy]$ ]] && cmd_setup_docker
    
    log_success "安装完成！请运行: source ~/.bashrc"
    cmd_doctor
}

cmd_setup_rust() {
    log_step "安装 Rust..."
    
    if command -v rustc &> /dev/null; then
        log_warning "Rust 已安装: $(rustc --version)"
        read -p "  重新安装? (y/N): " r
        [[ ! $r =~ ^[Yy]$ ]] && return
    fi
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    
    # 配置环境变量
    if ! grep -q "CARGO_HOME" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# Rust 环境变量
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
export PATH="$CARGO_HOME/bin:$PATH"
EOF
    fi
    
    # 配置国内镜像
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"
EOF
    
    rustup component add clippy rustfmt
    log_success "Rust 安装完成"
}

cmd_setup_flutter() {
    log_step "安装 Flutter..."
    
    local flutter_dir="$HOME/development/flutter"
    
    if [[ -d "$flutter_dir" ]]; then
        log_warning "Flutter 已存在: $flutter_dir"
        read -p "  重新安装? (y/N): " r
        [[ $r =~ ^[Yy]$ ]] && rm -rf "$flutter_dir"
        [[ ! $r =~ ^[Yy]$ ]] && return
    fi
    
    mkdir -p "$HOME/development"
    git clone https://github.com/flutter/flutter.git -b stable "$flutter_dir"
    
    # 配置环境变量
    if ! grep -q "FLUTTER_HOME" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# Flutter 环境变量
export FLUTTER_HOME="$HOME/development/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
EOF
    fi
    
    export PATH="$flutter_dir/bin:$PATH"
    flutter precache
    flutter doctor
    log_success "Flutter 安装完成"
}

cmd_setup_node() {
    log_step "安装 Node.js..."
    
    if command -v node &> /dev/null; then
        log_warning "Node.js 已安装: $(node --version)"
        return
    fi
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    npm config set registry https://registry.npmmirror.com
    log_success "Node.js 安装完成"
}

cmd_setup_docker() {
    log_step "安装 Docker..."
    
    if command -v docker &> /dev/null; then
        log_warning "Docker 已安装"
        return
    fi
    
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    log_success "Docker 安装完成，请重新登录使权限生效"
}

cmd_update() {
    log_step "更新工具链..."
    command -v rustup &> /dev/null && rustup update
    command -v flutter &> /dev/null && flutter upgrade
    log_success "更新完成"
}

# ============================================
# 主入口
# ============================================
main() {
    cd "$PROJECT_ROOT"
    
    case "${1:-help}" in
        setup)        cmd_setup ;;
        setup:rust)   cmd_setup_rust ;;
        setup:flutter) cmd_setup_flutter ;;
        setup:node)   cmd_setup_node ;;
        setup:docker) cmd_setup_docker ;;
        test)         cmd_test ;;
        test:rust)    cmd_test_rust ;;
        test:flutter) cmd_test_flutter ;;
        test:mini)    cmd_test_mini ;;
        build)        cmd_build ;;
        lint)         cmd_lint ;;
        fmt)          cmd_fmt ;;
        clean)        cmd_clean ;;
        start)        cmd_start ;;
        stop)         cmd_stop ;;
        logs)         cmd_logs ;;
        doctor)       cmd_doctor ;;
        update)       cmd_update ;;
        help|*)       show_help ;;
    esac
}

main "$@"
