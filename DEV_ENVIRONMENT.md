# 跨平台远程桌面客户端开发环境文档

## 概述

本文档描述了跨平台远程桌面客户端项目的完整开发环境配置和使用方法。开发环境支持 Rust 核心引擎、Flutter 统一客户端、微信小程序以及完整的 CI/CD 流水线。

## 系统要求

- **操作系统**: Ubuntu 24.04 LTS (推荐) 或其他 Ubuntu 版本
- **内存**: 最少 8GB RAM (推荐 16GB+)
- **存储**: 最少 50GB 可用空间
- **网络**: 稳定的互联网连接

## 快速开始

### 1. 一键安装开发环境

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/your-repo/remote-desktop-client/main/setup-dev-env.sh

# 给脚本执行权限
chmod +x setup-dev-env.sh

# 运行安装脚本（普通用户）
./setup-dev-env.sh

# 或者使用 root 用户（会显示警告但允许继续）
sudo ./setup-dev-env.sh
```

### 2. 重新加载环境变量

```bash
# 重新加载 bashrc
source ~/.bashrc

# 或者重新登录终端
```

### 3. 验证安装

```bash
# 检查 Rust
rustc --version
cargo --version

# 检查 Flutter
flutter doctor

# 检查 Node.js
node --version
npm --version

# 检查 Docker
docker --version

# 检查 Git
git --version
```

## 开发环境组件

### 1. Rust 开发环境

#### 安装位置
- **普通用户**: `~/.cargo/`
- **Root 用户**: `/opt/rust/`

#### 包含组件
- Rust 编译器 (rustc)
- Cargo 包管理器
- Clippy 代码检查工具
- Rustfmt 代码格式化工具
- WebAssembly 目标支持
- 常用 Cargo 工具:
  - `cargo-watch` - 文件监控和自动重新编译
  - `cargo-edit` - 依赖管理
  - `cargo-audit` - 安全审计
  - `cargo-outdated` - 依赖更新检查

#### 使用方法

```bash
# 创建新的 Rust 项目
cd ~/workspace/rust-projects  # 普通用户
cd /opt/workspace/rust-projects  # Root 用户
cargo new my-project
cd my-project

# 编译和运行
cargo run

# 运行测试
cargo test

# 代码检查
cargo clippy

# 代码格式化
cargo fmt

# 监控文件变化并自动重新编译
cargo watch -x run
```

### 2. Flutter 开发环境

#### 安装位置
- **普通用户**: `~/development/flutter/`
- **Root 用户**: `/opt/flutter/`

#### 支持平台
- Android
- iOS (需要 macOS)
- Web
- Linux Desktop
- Windows Desktop (需要 Windows)
- macOS Desktop (需要 macOS)

#### 使用方法

```bash
# 检查 Flutter 环境
flutter doctor

# 创建新的 Flutter 项目
cd ~/workspace/flutter-projects  # 普通用户
cd /opt/workspace/flutter-projects  # Root 用户
flutter create my_app
cd my_app

# 运行应用 (Web)
flutter run -d chrome

# 运行应用 (Android - 需要连接设备或模拟器)
flutter run -d android

# 构建应用
flutter build web
flutter build apk
flutter build linux

# 运行测试
flutter test

# 分析代码
flutter analyze
```

### 3. Node.js 和微信小程序开发环境

#### 安装组件
- Node.js 20.x LTS
- npm 包管理器
- Yarn 包管理器
- pnpm 包管理器
- 微信小程序 CLI 工具

#### 使用方法

```bash
# 检查版本
node --version
npm --version

# 创建微信小程序项目
cd ~/workspace/miniprogram-projects  # 普通用户
cd /opt/workspace/miniprogram-projects  # Root 用户

# 使用微信开发者工具创建项目
# 或者使用 CLI 工具
npx @wechat-miniprogram/cli create my-miniprogram
```

### 4. Android SDK (可选)

#### 安装位置
- **普通用户**: `~/Android/Sdk/`
- **Root 用户**: `/opt/Android/Sdk/`

#### 环境变量
```bash
export ANDROID_HOME=$HOME/Android/Sdk  # 普通用户
export ANDROID_HOME=/opt/Android/Sdk  # Root 用户
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
```

#### 使用方法

```bash
# 列出已安装的包
sdkmanager --list

# 安装新的 Android 平台
sdkmanager "platforms;android-33"

# 创建 AVD (Android Virtual Device)
avdmanager create avd -n test_avd -k "system-images;android-33;google_apis;x86_64"

# 启动模拟器
emulator -avd test_avd
```

### 5. Docker 开发环境

#### 使用方法

```bash
# 检查 Docker 状态
docker --version
docker info

# 运行容器
docker run hello-world

# 构建镜像
docker build -t my-app .

# 使用 Docker Compose
docker compose up -d
docker compose down
```

### 6. VS Code 开发环境

#### 已安装扩展
- Rust Analyzer - Rust 语言支持
- Flutter - Flutter 开发支持
- Dart - Dart 语言支持
- TypeScript - TypeScript 支持
- Tailwind CSS - CSS 框架支持
- JSON - JSON 文件支持
- YAML - YAML 文件支持
- Remote Containers - 容器开发支持
- GitHub Copilot - AI 代码助手

#### 使用方法

```bash
# 在当前目录打开 VS Code
code .

# 打开特定文件
code filename.rs

# 安装额外扩展
code --install-extension extension-id
```

## 项目结构

### 工作区目录
- **普通用户**: `~/workspace/`
- **Root 用户**: `/opt/workspace/`

```
workspace/
├── rust-projects/          # Rust 项目目录
├── flutter-projects/       # Flutter 项目目录
├── miniprogram-projects/   # 微信小程序项目目录
├── docker-configs/         # Docker 配置文件
├── scripts/               # 开发脚本
└── README.md              # 工作区说明
```

### 项目目录结构

```
remote-desktop-client/
├── Cargo.toml                    # Rust 工作区配置
├── rust-core/                   # Rust 核心引擎
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs
│   │   ├── webrtc_engine.rs
│   │   ├── signaling.rs
│   │   ├── screen_capture.rs
│   │   ├── input_control.rs
│   │   ├── file_transfer.rs
│   │   ├── session_manager.rs
│   │   ├── security.rs
│   │   ├── network.rs
│   │   └── ffi.rs
│   └── build.rs
├── flutter-client/              # Flutter 统一客户端
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   └── src/
│   │       ├── app.dart
│   │       ├── core/
│   │       └── features/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── windows/
│   ├── macos/
│   └── linux/
├── wechat-miniprogram/          # 微信小程序
│   ├── app.json
│   ├── app.js
│   ├── app.wxss
│   └── pages/
└── docs/                        # 文档目录
```

## 开发工作流

### 1. Rust 核心引擎开发

```bash
# 进入 Rust 项目目录
cd rust-core

# 开发时监控文件变化
cargo watch -x "test" -x "run"

# 运行测试
cargo test

# 生成文档
cargo doc --open

# 发布构建
cargo build --release
```

### 2. Flutter 客户端开发

```bash
# 进入 Flutter 项目目录
cd flutter-client

# 获取依赖
flutter pub get

# 运行应用 (开发模式)
flutter run -d chrome  # Web
flutter run -d linux   # Linux Desktop

# 热重载 (在运行时按 'r')
# 热重启 (在运行时按 'R')

# 运行测试
flutter test

# 构建发布版本
flutter build web
flutter build linux
flutter build apk
```

### 3. 微信小程序开发

```bash
# 进入小程序项目目录
cd wechat-miniprogram

# 使用微信开发者工具打开项目
# 或者使用 CLI 工具进行构建和预览
```

### 4. 跨语言 FFI 开发

Rust 核心引擎通过 FFI (Foreign Function Interface) 与 Flutter 客户端通信：

```rust
// Rust 端 (rust-core/src/ffi.rs)
#[no_mangle]
pub extern "C" fn webrtc_engine_create() -> WebRTCEngineHandle {
    // 实现
}
```

```dart
// Flutter 端 (flutter-client/lib/src/core/rust_bridge/rust_bridge.dart)
static Pointer<Void>? createWebRTCEngine() {
  final handle = _webrtcEngineCreate();
  return handle != 0 ? Pointer<Void>.fromAddress(handle) : null;
}
```

## CI/CD 配置

### GitHub Actions 工作流

创建 `.github/workflows/ci.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  rust-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
    - name: Run Rust tests
      run: |
        cd rust-core
        cargo test

  flutter-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    - name: Run Flutter tests
      run: |
        cd flutter-client
        flutter test

  build-and-deploy:
    needs: [rust-tests, flutter-tests]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Build and deploy
      run: |
        # 构建和部署逻辑
```

### Docker 配置

#### Rust 核心引擎 Dockerfile

```dockerfile
# rust-core/Dockerfile
FROM rust:1.75 as builder

WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/remote_desktop_core /usr/local/bin/
CMD ["remote_desktop_core"]
```

#### Flutter Web Dockerfile

```dockerfile
# flutter-client/Dockerfile.web
FROM cirrusci/flutter:stable as builder

WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### Docker Compose 配置

```yaml
# docker-compose.yml
version: '3.8'

services:
  rust-core:
    build:
      context: ./rust-core
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - RUST_LOG=info

  flutter-web:
    build:
      context: ./flutter-client
      dockerfile: Dockerfile.web
    ports:
      - "3000:80"
    depends_on:
      - rust-core

  signaling-server:
    build:
      context: ./signaling-server
      dockerfile: Dockerfile
    ports:
      - "8081:8081"
    environment:
      - NODE_ENV=production
```

## 调试和测试

### 1. Rust 调试

```bash
# 使用 GDB 调试
rust-gdb target/debug/my-program

# 使用 LLDB 调试
rust-lldb target/debug/my-program

# 启用详细日志
RUST_LOG=debug cargo run
```

### 2. Flutter 调试

```bash
# 启用调试模式
flutter run --debug

# 性能分析
flutter run --profile

# 检查器
flutter inspector
```

### 3. 单元测试

```bash
# Rust 测试
cd rust-core
cargo test

# Flutter 测试
cd flutter-client
flutter test

# 集成测试
cd flutter-client
flutter drive --target=test_driver/app.dart
```

### 4. 性能测试

```bash
# Rust 基准测试
cd rust-core
cargo bench

# Flutter 性能测试
cd flutter-client
flutter test --coverage
```

## 常见问题和解决方案

### 1. Rust 编译问题

**问题**: 编译时出现链接错误
```bash
# 解决方案：安装必要的系统库
sudo apt install build-essential pkg-config libssl-dev
```

**问题**: Cargo 下载依赖慢
```bash
# 解决方案：配置国内镜像源
mkdir -p ~/.cargo
cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"
EOF
```

### 2. Flutter 问题

**问题**: Flutter doctor 显示问题
```bash
# 解决方案：按照提示安装缺失组件
flutter doctor --android-licenses  # 接受 Android 许可证
```

**问题**: Web 应用无法访问摄像头
```bash
# 解决方案：使用 HTTPS 或 localhost
flutter run -d chrome --web-port=3000 --web-hostname=localhost
```

### 3. Docker 问题

**问题**: 权限被拒绝
```bash
# 解决方案：将用户添加到 docker 组
sudo usermod -aG docker $USER
# 然后重新登录
```

**问题**: 容器无法访问网络
```bash
# 解决方案：检查防火墙设置
sudo ufw status
sudo ufw allow 8080/tcp
```

### 4. 微信小程序问题

**问题**: 开发者工具无法启动
```bash
# 解决方案：检查依赖库
sudo apt install libgtk-3-0 libxss1 libasound2
```

## 性能优化建议

### 1. 编译优化

```toml
# Cargo.toml
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = 'abort'
```

### 2. Flutter 优化

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/
  fonts:
    - family: CustomFont
      fonts:
        - asset: fonts/CustomFont.ttf
```

### 3. 系统优化

```bash
# 增加文件监控限制
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 优化 Git 性能
git config --global core.preloadindex true
git config --global core.fscache true
```

## 更新和维护

### 1. 更新 Rust

```bash
rustup update
```

### 2. 更新 Flutter

```bash
flutter upgrade
```

### 3. 更新 Node.js

```bash
# 使用 n 版本管理器
sudo npm install -g n
sudo n latest
```

### 4. 更新系统包

```bash
sudo apt update && sudo apt upgrade
```

## 团队协作

### 1. 代码规范

- Rust: 使用 `rustfmt` 和 `clippy`
- Flutter: 使用 `dart format` 和 `flutter analyze`
- Git: 使用 Conventional Commits 规范

### 2. 分支策略

- `main`: 生产分支
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 热修复分支

### 3. 代码审查

- 所有代码必须通过 Pull Request
- 至少需要一个审查者批准
- 必须通过所有 CI 检查

## 支持和帮助

### 官方文档
- [Rust 官方文档](https://doc.rust-lang.org/)
- [Flutter 官方文档](https://flutter.dev/docs)
- [微信小程序文档](https://developers.weixin.qq.com/miniprogram/dev/framework/)

### 社区资源
- [Rust 中文社区](https://rustcc.cn/)
- [Flutter 中文网](https://flutter.cn/)
- [Docker 中文文档](https://docs.docker-cn.com/)

### 问题反馈
如果遇到问题，请在项目 GitHub 仓库提交 Issue，或联系开发团队。

---

**最后更新**: 2024年1月1日
**文档版本**: 1.0.0