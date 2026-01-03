# CEC Remote - 工一远控

跨平台远程桌面解决方案，支持控制端与被控端双向功能。基于 Rust 核心引擎 + Flutter 统一界面架构。

## 快速开始

```bash
# 克隆项目
git clone https://github.com/your-org/cec-remote.git
cd cec-remote

# 一键安装开发环境 (Ubuntu)
./setup-dev-env.sh

# 重新加载环境变量
source ~/.bashrc

# 运行测试
./scripts/run-all-tests.sh
```

## 项目结构

```
cec-remote/
├── rust-core/           # Rust 核心引擎 (WebRTC, 编解码, 安全)
├── flutter-client/      # Flutter 统一客户端 (Android/iOS/Web/Desktop)
├── wechat-miniprogram/  # 微信小程序客户端
├── docker/              # Docker 配置
└── scripts/             # 开发脚本
```

## 开发

```bash
# Rust 核心
cd rust-core && cargo test

# Flutter 客户端
cd flutter-client && flutter run -d chrome

# 微信小程序
cd wechat-miniprogram && npm test
```

## 构建

```bash
# Android APK
cd flutter-client && flutter build apk

# Web
cd flutter-client && flutter build web

# Linux Desktop
cd flutter-client && flutter build linux
```

## 文档

- [开发环境配置](DEV_ENVIRONMENT.md) - 详细的环境搭建和使用说明

## License

MIT

