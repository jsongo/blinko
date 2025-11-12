#!/bin/bash

set -e  # 遇到错误立即退出

echo "🚀 Building Blinko Desktop App for ARM macOS..."

# 检查 Rust 是否已安装
if ! command -v rustc &> /dev/null; then
    echo "❌ Rust is not installed!"
    echo "📦 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
fi

# 显示版本信息
echo "✅ Rust version: $(rustc --version)"
echo "✅ Cargo version: $(cargo --version)"
echo "✅ System architecture: $(uname -m)"

# 进入 app 目录
cd app || exit 1

# 安装依赖
echo "📦 Installing dependencies..."
bun install

# 清理之前的构建
echo "🧹 Cleaning previous builds..."
rm -rf src-tauri/target/release/bundle 2>/dev/null || true

# 构建桌面应用
echo "🔨 Building Tauri app (this may take 5-10 minutes)..."
echo "⏳ Please wait..."

# 使用 verbose 模式查看进度
bun run tauri build --verbose

echo ""
echo "✨ Build complete!"
echo "📦 App location: src-tauri/target/release/bundle/macos/Blinko.app"
echo "💿 DMG location: src-tauri/target/release/bundle/dmg/"
ls -lh src-tauri/target/release/bundle/dmg/ 2>/dev/null || true
