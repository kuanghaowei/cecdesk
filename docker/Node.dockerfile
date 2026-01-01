# Node.js 开发环境 Dockerfile
FROM node:20-alpine

# 安装系统依赖
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++

# 安装全局工具
RUN npm install -g \
    @wechat-miniprogram/cli \
    nodemon \
    typescript \
    ts-node

# 设置工作目录
WORKDIR /workspace

# 复制 package.json
COPY signaling-server/package*.json ./

# 安装依赖
RUN npm ci

# 暴露端口
EXPOSE 3000

CMD ["npm", "run", "dev"]