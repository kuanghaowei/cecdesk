#!/bin/bash

# 测试脚本 - 验证 root 用户支持

set -e

# 全局变量
IS_ROOT=false
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 辅助函数：根据用户类型执行命令
run_as_admin() {
    if [[ $IS_ROOT == true ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 测试基础功能
test_basic_functions() {
    log_info "测试基础功能..."
    
    # 测试用户检测
    check_root
    
    if [[ $IS_ROOT == true ]]; then
        log_success "Root 用户检测正常"
        log_info "工作目录将设置为: /opt/workspace"
        log_info "Flutter 将安装到: /opt/flutter"
        log_info "Rust 将安装到: /opt/rust"
    else
        log_success "普通用户检测正常"
        log_info "工作目录将设置为: ~/workspace"
        log_info "Flutter 将安装到: ~/development/flutter"
        log_info "Rust 将安装到: ~/.cargo"
    fi
    
    # 测试命令执行函数
    log_info "测试命令执行函数..."
    if run_as_admin echo "命令执行测试成功"; then
        log_success "命令执行函数正常"
    else
        log_error "命令执行函数异常"
        return 1
    fi
    
    log_success "所有基础功能测试通过"
}

# 测试系统信息
test_system_info() {
    log_info "系统信息:"
    log_info "用户: $(whoami)"
    log_info "用户ID: $(id -u)"
    log_info "系统: $(lsb_release -d | cut -f2)"
    log_info "内核: $(uname -r)"
    log_info "架构: $(uname -m)"
}

# 主函数
main() {
    log_info "开始测试脚本..."
    
    test_system_info
    echo
    test_basic_functions
    
    echo
    log_success "测试完成！脚本可以正常处理 root 用户"
    
    if [[ $IS_ROOT == true ]]; then
        log_info "您可以继续运行完整的安装脚本: ./setup-dev-env.sh"
    else
        log_info "您可以继续运行完整的安装脚本: ./setup-dev-env.sh"
        log_info "或者使用 root 用户运行: sudo ./setup-dev-env.sh"
    fi
}

main "$@"