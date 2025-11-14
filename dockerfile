# ============================================
# Stage 1: Dependencies - 安装构建时依赖 (会被缓存)
# ============================================
FROM oven/bun:1.2.8 AS deps

ARG USE_MIRROR=false

WORKDIR /app

ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1
ENV npm_config_sharp_binary_host="https://npmmirror.com/mirrors/sharp"
ENV npm_config_sharp_libvips_binary_host="https://npmmirror.com/mirrors/sharp-libvips"
ENV PRISMA_ENGINES_MIRROR="https://registry.npmmirror.com/-/binary/prisma"
ENV PRISMA_SKIP_POSTINSTALL_GENERATE=true
# 跳过一些耗时的 postinstall
ENV SKIP_POSTINSTALL=1
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# 配置镜像
RUN if [ "$USE_MIRROR" = "true" ]; then \
    echo "Using Taobao Mirror to Install Dependencies" && \
    echo '{ "install": { "registry": "https://registry.npmmirror.com" } }' > .bunfig.json && \
    cat .bunfig.json; \
    fi

# 只复制依赖文件 (package.json 不变时这层会被缓存)
COPY package.json bun.lock turbo.json ./
COPY tsconfig*.json ./
COPY .npmrc ./
COPY prisma ./prisma
COPY server/package.json server/tsconfig*.json ./server/
COPY app/package.json app/tsconfig*.json ./app/
COPY shared/package.json shared/tsconfig*.json ./shared/
COPY blinko-types/package.json ./blinko-types/
COPY shared ./shared

# 复制 app/tauri-plugin-blinko (Web 构建需要这个插件)
COPY app/tauri-plugin-blinko ./app/tauri-plugin-blinko

# 安装依赖 - 简化输出
RUN echo "========================" && \
    echo "Starting bun install..." && \
    echo "Bun version:" && bun --version && \
    echo "========================" && \
    bun install --unsafe-perm 2>&1 | grep -E "(packages installed|error|warn|failed)" || bun install --unsafe-perm && \
    echo "========================" && \
    echo "Installation completed!" && \
    echo "========================"

# ARM 架构 sharp 预安装 (跳过,因为在 runtime-deps 阶段会统一安装)
# 在 QEMU 模拟环境中安装容易失败,所以注释掉
# RUN if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then \
#     echo "Detected ARM architecture, installing sharp..." && \
#     bun install --platform=linux --arch=arm64 sharp@0.34.1 --no-save --unsafe-perm || \
#     bun install --force @img/sharp-linux-arm64 --no-save; \
#     fi

# 生成 Prisma Client (schema 不变时会使用缓存)
RUN bunx prisma generate


# ============================================
# Stage 2: Builder - 构建应用 (只有代码变化时才重新构建)
# ============================================
FROM oven/bun:1.2.8 AS builder

# 内存限制参数 (可在构建时覆盖)
# CI 环境(16GB RAM): 使用 --build-arg BUILD_MEMORY=8192
# 本地环境(有限内存): 使用默认值 2048
ARG BUILD_MEMORY=2048

WORKDIR /app

# 从 deps 阶段复制 node_modules 和 Prisma Client (避免重新安装)
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./package.json

# 复制源代码
COPY . .

# 确保 Prisma Client 已生成
RUN echo "Checking Prisma Client..." && \
    ls -la node_modules/.prisma/client 2>/dev/null || bunx prisma generate

# 构建应用 (分开构建以减少内存压力)
# 注意：本地构建需要至少 8GB Docker 内存
# 推荐使用 GitHub Actions 云端构建（见 BUILD_DOCKER_CLOUD.md）

# 验证 BUILD_MEMORY 参数
RUN echo "========================================" && \
    echo "Build Configuration:" && \
    echo "BUILD_MEMORY = ${BUILD_MEMORY} MB" && \
    echo "NODE_OPTIONS will be set to: --max-old-space-size=${BUILD_MEMORY}" && \
    echo "========================================"

# 先构建 backend
RUN echo "Building backend with ${BUILD_MEMORY}MB memory limit..." && \
    export NODE_OPTIONS="--max-old-space-size=${BUILD_MEMORY}" && \
    cd server && bun run build:web && cd ..

# 再构建 frontend (使用 Docker 优化配置)
RUN echo "======================================" && \
    echo "Building frontend with ${BUILD_MEMORY}MB memory limit..." && \
    echo "Using optimized Docker config: vite.config.docker.ts" && \
    echo "Available CPU cores: $(nproc)" && \
    echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')" && \
    echo "======================================" && \
    cd app && \
    DISABLE_PWA=true \
    NODE_OPTIONS="--max-old-space-size=${BUILD_MEMORY}" \
    UV_THREADPOOL_SIZE=4 \
    bun run ../node_modules/.bin/vite build --config vite.config.docker.ts --logLevel info && \
    echo "======================================" && \
    echo "Frontend build completed: $(date '+%Y-%m-%d %H:%M:%S')" && \
    echo "======================================" && \
    cd ..

RUN echo "Starting build:seed..." && \
    bun run build:seed 2>&1 || (echo "Build seed failed! Check the error above." && exit 1)

# 生成启动脚本（带错误处理）
RUN printf '#!/bin/sh\n\
set -e\n\
\n\
echo "========================================="\n\
echo "Starting Blinko..."\n\
echo "Environment: $NODE_ENV"\n\
echo "========================================="\n\
\n\
echo "Running database migrations..."\n\
npx prisma migrate deploy || {\n\
  echo "ERROR: Database migration failed!"\n\
  exit 1\n\
}\n\
\n\
echo "Running database seed..."\n\
node server/seed.js || {\n\
  echo "WARNING: Database seed failed, but continuing..."\n\
}\n\
\n\
echo "Starting application server..."\n\
exec node server/index.js\n' > start.sh && \
    chmod +x start.sh


# ============================================
# Stage 3: Init Downloader - 下载工具 (会被缓存)
# ============================================
FROM node:20-alpine AS init-downloader

WORKDIR /app

RUN wget -qO /app/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m) && \
    chmod +x /app/dumb-init && \
    rm -rf /var/cache/apk/*


# ============================================
# Stage 4: Runtime Dependencies - 安装运行时依赖 (会被缓存)
# ============================================
FROM node:20-alpine AS runtime-deps

ARG USE_MIRROR=true

WORKDIR /app

ENV NODE_ENV=production
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1
ENV npm_config_sharp_binary_host="https://npmmirror.com/mirrors/sharp"
ENV npm_config_sharp_libvips_binary_host="https://npmmirror.com/mirrors/sharp-libvips"

# 安装构建工具和运行时库
RUN apk add --no-cache openssl vips-dev python3 py3-setuptools make g++ gcc libc-dev linux-headers && \
    if [ "$USE_MIRROR" = "true" ]; then \
    npm config set registry https://registry.npmmirror.com; \
    fi

# 复制 package.json 用于安装依赖 (不变时会使用缓存)
COPY --from=builder /app/package.json ./package.json

# 安装运行时依赖 (统一安装,包括 sharp)
# sharp 会根据当前架构自动下载正确的预编译二进制
RUN npm install @node-rs/crc32 lightningcss sharp@0.34.1 prisma@6.19.0 && \
    npm install -g prisma@6.19.0 && \
    npm install sqlite3@5.1.7 && \
    npm install llamaindex @langchain/community@0.3.40 && \
    npm install @libsql/client @libsql/core

# 清理构建工具 (保留 openssl 和 vips-dev)
RUN apk del python3 py3-setuptools make g++ gcc libc-dev linux-headers && \
    rm -rf /var/cache/apk/* /root/.npm /root/.cache


# ============================================
# Stage 5: Final Runner - 最终运行镜像 (最小化)
# ============================================
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV DISABLE_SECURE_COOKIE=false
ENV TRUST_PROXY=1

# 只安装运行时必需的库 (不需要构建工具)
RUN apk add --no-cache openssl vips-dev && \
    rm -rf /var/cache/apk/*

# 从各个阶段复制必要文件
COPY --from=builder /app/dist ./server
COPY --from=builder /app/server/lute.min.js ./server/lute.min.js
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/start.sh ./
COPY --from=init-downloader /app/dumb-init /usr/local/bin/dumb-init

# 从 deps 复制 Prisma Client
COPY --from=deps /app/node_modules/.prisma/client ./node_modules/.prisma/client

# 从 runtime-deps 复制运行时依赖
COPY --from=runtime-deps /app/node_modules ./node_modules
COPY --from=runtime-deps /usr/local/lib/node_modules/prisma /usr/local/lib/node_modules/prisma
COPY --from=runtime-deps /usr/local/bin/prisma /usr/local/bin/prisma

# 重新生成 Prisma Client (确保路径正确)
RUN npx prisma generate

RUN chmod +x ./start.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:1111/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Expose Port (Adjust According to Actual Application)
EXPOSE 1111

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["/bin/sh", "-c", "./start.sh"]
