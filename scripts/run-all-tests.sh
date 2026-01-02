#!/bin/bash
# 统一测试脚本 - 在本地运行所有测试

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  CEC Remote - 统一测试脚本${NC}"
echo -e "${YELLOW}========================================${NC}"

# 记录开始时间
START_TIME=$(date +%s)

# 测试结果
RUST_RESULT=0
FLUTTER_RESULT=0
MINIPROGRAM_RESULT=0

# ============================================
# Rust 测试
# ============================================
echo -e "\n${YELLOW}[1/3] 运行 Rust 测试...${NC}"
if cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings && cargo test --all; then
    echo -e "${GREEN}✓ Rust 测试通过${NC}"
else
    echo -e "${RED}✗ Rust 测试失败${NC}"
    RUST_RESULT=1
fi

# ============================================
# Flutter 测试
# ============================================
echo -e "\n${YELLOW}[2/3] 运行 Flutter 测试...${NC}"
cd flutter-client
if flutter analyze && flutter test; then
    echo -e "${GREEN}✓ Flutter 测试通过${NC}"
else
    echo -e "${RED}✗ Flutter 测试失败${NC}"
    FLUTTER_RESULT=1
fi
cd ..

# ============================================
# 微信小程序测试
# ============================================
echo -e "\n${YELLOW}[3/3] 运行微信小程序测试...${NC}"
cd wechat-miniprogram
if npm test; then
    echo -e "${GREEN}✓ 微信小程序测试通过${NC}"
else
    echo -e "${RED}✗ 微信小程序测试失败${NC}"
    MINIPROGRAM_RESULT=1
fi
cd ..

# ============================================
# 汇总结果
# ============================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}  测试结果汇总${NC}"
echo -e "${YELLOW}========================================${NC}"

if [ $RUST_RESULT -eq 0 ]; then
    echo -e "  Rust:        ${GREEN}✓ 通过${NC}"
else
    echo -e "  Rust:        ${RED}✗ 失败${NC}"
fi

if [ $FLUTTER_RESULT -eq 0 ]; then
    echo -e "  Flutter:     ${GREEN}✓ 通过${NC}"
else
    echo -e "  Flutter:     ${RED}✗ 失败${NC}"
fi

if [ $MINIPROGRAM_RESULT -eq 0 ]; then
    echo -e "  小程序:      ${GREEN}✓ 通过${NC}"
else
    echo -e "  小程序:      ${RED}✗ 失败${NC}"
fi

echo -e "\n  总耗时: ${DURATION}秒"

# 返回最终结果
if [ $RUST_RESULT -eq 0 ] && [ $FLUTTER_RESULT -eq 0 ] && [ $MINIPROGRAM_RESULT -eq 0 ]; then
    echo -e "\n${GREEN}✓ 所有测试通过！可以安全提交。${NC}"
    exit 0
else
    echo -e "\n${RED}✗ 部分测试失败，请修复后再提交。${NC}"
    exit 1
fi
