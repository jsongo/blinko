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
ENV SKIP_POSTINSTALL=1
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# 配置镜像
RUN if [ "$USE_MIRROR" = "true" ]; then \
    echo "Using Taobao Mirror to Install Dependencies" && \
    echo '{ "install": { "registry": "https://registry.npmmirror.com" } }' > .bunfig.json && \
    cat .bunfig.json; \
    fi

# 优化: 先复制 lock 文件，单独一层缓存
COPY bun.lock package.json ./

# 优化: 复制配置文件（变化频率低）
COPY turbo.json tsconfig*.json .npmrc ./

# 优化: 复制 prisma schema（变化频率低）
COPY prisma ./prisma

# 优化: 复制各模块的 package.json（一次复制，避免多层）
COPY server/package.json server/tsconfig*.json ./server/
COPY app/package.json app/tsconfig*.json ./app/
COPY shared/package.json shared/tsconfig*.json ./shared/
COPY blinko-types/package.json ./blinko-types/

# 优化: 复制 shared 和插件（构建依赖）
COPY shared ./shared
COPY app/tauri-plugin-blinko ./app/tauri-plugin-blinko

# 安装依赖 - 优化输出，减少日志大小
RUN echo "Installing dependencies with Bun $(bun --version)..." && \
    bun install --frozen-lockfile --unsafe-perm 2>&1 | \
    grep -E "(packages installed|error|warn|failed)" || \
    bun install --frozen-lockfile --unsafe-perm && \
    echo "✓ Dependencies installed"

# 生成 Prisma Client
RUN bunx prisma generate && \
    echo "✓ Prisma Client generated"


# ============================================
# Stage 2: Builder - 构建应用
# ============================================
FROM oven/bun:1.2.8 AS builder

ARG BUILD_MEMORY=2048

WORKDIR /app

# 从 deps 复制依赖（避免重新安装）
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./package.json

# 优化: 只复制构建需要的文件
COPY --from=deps /app/prisma ./prisma
COPY --from=deps /app/tsconfig*.json ./
COPY --from=deps /app/turbo.json ./turbo.json

# 复制源代码
COPY server ./server
COPY app ./app
COPY shared ./shared
COPY blinko-types ./blinko-types

# 验证 Prisma Client
RUN ls -la node_modules/.prisma/client 2>/dev/null || bunx prisma generate

# 设置构建环境变量
ENV NODE_OPTIONS="--max-old-space-size=${BUILD_MEMORY}"
ENV UV_THREADPOOL_SIZE=4

# 优化: 串行构建，减少内存峰值
RUN echo "Building backend (memory: ${BUILD_MEMORY}MB)..." && \
    cd server && \
    bun run build:web && \
    echo "✓ Backend built" && \
    cd ..

RUN echo "Building frontend (memory: ${BUILD_MEMORY}MB)..." && \
    cd app && \
    DISABLE_PWA=true \
    bun run ../node_modules/.bin/vite build --config vite.config.docker.ts --logLevel warn && \
    echo "✓ Frontend built" && \
    cd ..

RUN echo "Running build:seed..." && \
    bun run build:seed 2>&1 | grep -E "(error|warn|✓)" || bun run build:seed && \
    echo "✓ Seed completed"

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
# Stage 3: Runtime Dependencies - 运行时依赖
# ============================================
FROM node:20-alpine AS runtime-deps

ARG USE_MIRROR=true

WORKDIR /app

ENV NODE_ENV=production
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1
ENV npm_config_sharp_binary_host="https://npmmirror.com/mirrors/sharp"
ENV npm_config_sharp_libvips_binary_host="https://npmmirror.com/mirrors/sharp-libvips"

# 优化: 合并 apk 操作，减少层数
RUN apk add --no-cache openssl vips-dev python3 py3-setuptools make g++ gcc libc-dev linux-headers && \
    if [ "$USE_MIRROR" = "true" ]; then npm config set registry https://registry.npmmirror.com; fi && \
    rm -rf /var/cache/apk/*

# 复制 package.json
COPY --from=builder /app/package.json ./package.json

# 优化: 一次性安装所有运行时依赖，减少层数
RUN npm install --omit=dev --no-audit --no-fund --legacy-peer-deps \
    @node-rs/crc32 \
    lightningcss \
    sharp@0.34.1 \
    prisma@6.19.0 \
    @prisma/client@6.19.0 \
    sqlite3@5.1.7 \
    llamaindex \
    @langchain/community@0.3.40 \
    @libsql/client \
    @libsql/core && \
    npm install -g prisma@6.19.0 && \
    echo "✓ Runtime dependencies installed"

# 优化: 清理构建工具和缓存
RUN apk del python3 py3-setuptools make g++ gcc libc-dev linux-headers && \
    rm -rf /var/cache/apk/* /root/.npm /root/.cache /tmp/*


# ============================================
# Stage 4: Final Runner - 最终运行镜像
# ============================================
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV DISABLE_SECURE_COOKIE=false
ENV TRUST_PROXY=1

# 优化: 只安装必需的运行时库
RUN apk add --no-cache openssl vips-dev && \
    wget -qO /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m) && \
    chmod +x /usr/bin/dumb-init && \
    rm -rf /var/cache/apk/*

# 优化: 按变化频率排序复制，最常变化的放最后
COPY --from=runtime-deps /app/node_modules ./node_modules
COPY --from=runtime-deps /usr/local/lib/node_modules/prisma /usr/local/lib/node_modules/prisma
COPY --from=runtime-deps /usr/local/bin/prisma /usr/local/bin/prisma

# 先复制已有的 Prisma Client（作为 fallback）
COPY --from=deps /app/node_modules/.prisma/client ./node_modules/.prisma/client
COPY --from=builder /app/prisma ./prisma

# 重新生成 Prisma Client（确保架构匹配 arm64/amd64）
RUN npx prisma generate && echo "✓ Prisma Client ready"

COPY --from=builder /app/server/lute.min.js ./server/lute.min.js
COPY --from=builder /app/dist ./server
COPY --from=builder /app/start.sh ./start.sh

RUN chmod +x ./start.sh

# 优化: 添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:1111/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

EXPOSE 1111

# 使用 dumb-init 确保信号正确处理
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/sh", "-c", "./start.sh"]
