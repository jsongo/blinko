# GitHub Workflows 总览

项目中共有 **6 个 GitHub workflow 文件**：

## 1. **[app-release.yml](vscode-webview://1qr7ckis75onvnis1ipsrgf0ckrrji83qvhddobahutrnbjf78vr/.github/workflows/app-release.yml)** - 应用发布工作流

**触发方式**：

- 推送 tag 时
- repository_dispatch 事件（trigger-app-release）
- 手动触发（workflow_dispatch）  
  **主要功能**：
- **set-version**: 设置版本号
- **update-version**: 更新 tauri.conf.json 中的版本号并提交
- **publish-desktop**: 构建桌面应用（macOS, Linux, Windows）
  - 使用 Tauri Action 构建多平台桌面应用
  - 支持代码签名（TAURI_SIGNING_PRIVATE_KEY）
  - 支持测试模式（不发布，仅上传 artifacts）
- **publish-android**: 构建 Android APK
  - 配置 NDK 27.0.11902837
  - 使用 keystore 签名
  - 生成 universal APK
- **generate-changelog**: 使用 tag-changelog 生成更新日志
- **update-release**: 更新 GitHub Release 的 changelog
- **process-notification**: 使用 OpenRouter AI 生成中英文通知消息
- **notify-telegram**: 发送 Telegram 通知到两个群组

## 2. **[build-publish-release.yml](vscode-webview://1qr7ckis75onvnis1ipsrgf0ckrrji83qvhddobahutrnbjf78vr/.github/workflows/build-publish-release.yml)** - Docker 镜像构建发布

**触发方式**：

- Release 发布时（published）
- 手动触发  
  **主要功能**：
- **update-version**: 更新 package.json 版本号
- **build**: 多架构 Docker 镜像构建
  - linux/amd64（ubuntu-latest）
  - linux/arm64（ubuntu-24.04-arm）
  - 使用 GitHub Actions cache 优化构建
- **merge**: 合并多架构镜像并推送
  - 推送到 Docker Hub（blinkospace/blinko）
  - 推送到 GitHub Container Registry（ghcr.io/blinkospace/blinko）
- **trigger-app-release**: 可选同时触发应用发布

## 3. **[test-telegram-notification.yml](vscode-webview://1qr7ckis75onvnis1ipsrgf0ckrrji83qvhddobahutrnbjf78vr/.github/workflows/test-telegram-notification.yml)** - Telegram 通知测试

**触发方式**：

- 手动触发  
  **主要功能**：
- **get-latest-release**: 获取最新的 release 信息
- **process-content**: 使用 OpenRouter AI 生成中英文消息
- **test-telegram**: 发送测试通知到 Telegram 群组
  - 支持自定义 chat ID 测试
  - 同时测试两个群组

## 4. **[mark-stable.yml](vscode-webview://1qr7ckis75onvnis1ipsrgf0ckrrji83qvhddobahutrnbjf78vr/.github/workflows/mark-stable.yml)** - 标记稳定版本

**触发方式**：

- 手动触发，需要输入版本号  
  **主要功能**：
- 将指定版本的 Docker 镜像标记为 stable
- 同时更新 Docker Hub 和 GitHub Container Registry 的 stable tag

## 5. **[translator.yml](vscode-webview://1qr7ckis75onvnis1ipsrgf0ckrrji83qvhddobahutrnbjf78vr/.github/workflows/translator.yml)** - 自动翻译

**触发方式**：

- Issues/PR 创建或编辑时
- 评论创建或编辑时
- Discussions 创建或编辑时  
  **主要功能**：
- 使用 `lizheming/github-translate-action` 自动翻译 Issues、PR、讨论等内容
- 修改标题并追加翻译内容

## 6. **[windows-test-release.yml](vscode-webview://1qr7ckis75onvnis1ipsrgf0ckrrji83qvhddobahutrnbjf78vr/.github/workflows/windows-test-release.yml)** - Windows 测试构建

**触发方式**：

- 手动触发  
  **主要功能**：
- 测试 Windows 平台构建（不发布）
- 支持两种变体：
  - **CPU 版本**：`--features whisper-cpu`
  - **CUDA 版本**：`--features whisper-cuda`
    - 安装 CUDA Toolkit 12.5.0
    - 配置 Visual Studio CUDA 集成
- 只构建不打包（`--no-bundle`）

# 工作流特点

**自动化发布流程**：Tag 触发 → 构建多平台应用 → 生成 changelog → AI 处理通知 → Telegram 通知
**多平台支持**：macOS (ARM)、Linux、Windows、Android
**多架构 Docker**：同时构建 amd64 和 arm64
**AI 增强**：使用 OpenRouter API 生成中英文发布通知
**测试模式**：支持草稿发布和测试构建，不会触发通知
**缓存优化**：使用 Rust cache、Gradle cache、GitHub Actions cache
