# ============================================
# Stage 1: Dependencies - 安装所有依赖（构建时+运行时）
# ============================================
FROM oven/bun:1.2.8 AS deps

ARG USE_MIRROR=false

WORKDIR /app

# 环境变量配置
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1 \
    npm_config_sharp_binary_host="https://npmmirror.com/mirrors/sharp" \
    npm_config_sharp_libvips_binary_host="https://npmmirror.com/mirrors/sharp-libvips" \
    PRISMA_ENGINES_MIRROR="https://registry.npmmirror.com/-/binary/prisma" \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# 配置镜像（如果需要）
RUN if [ "$USE_MIRROR" = "true" ]; then \
    echo '{ "install": { "registry": "https://registry.npmmirror.com" } }' > .bunfig.json; \
    fi

# 缓存优化：先复制依赖文件（变化少）
COPY bun.lock package.json turbo.json tsconfig*.json .npmrc ./
COPY prisma ./prisma

# 复制各模块的 package.json（避免源代码变化导致重新安装依赖）
COPY server/package.json server/tsconfig*.json ./server/
COPY app/package.json app/tsconfig*.json ./app/
COPY shared/package.json shared/tsconfig*.json ./shared/
COPY blinko-types/package.json ./blinko-types/

# 复制构建依赖的源码
COPY shared ./shared
COPY app/tauri-plugin-blinko ./app/tauri-plugin-blinko

# 一次性安装所有依赖（开发+生产）
RUN bun install --frozen-lockfile --unsafe-perm && \
    bunx prisma generate && \
    echo "✓ Dependencies installed and Prisma Client generated"


# ============================================
# Stage 2: Builder - 构建应用
# ============================================
FROM oven/bun:1.2.8 AS builder

ARG BUILD_MEMORY=2048

WORKDIR /app

# 从 deps 复制依赖和配置
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json /app/turbo.json /app/tsconfig*.json ./
COPY --from=deps /app/prisma ./prisma

# 复制源代码（最后复制，利用缓存）
COPY server ./server
COPY app ./app
COPY shared ./shared
COPY blinko-types ./blinko-types

# 设置构建环境
ENV NODE_OPTIONS="--max-old-space-size=${BUILD_MEMORY}" \
    UV_THREADPOOL_SIZE=4

# 并行构建前后端（节省时间）
RUN set -e; \
    echo "Starting parallel builds..."; \
    (cd server && bun run build:web && echo "✓ Backend built") & \
    BACKEND_PID=$!; \
    (cd app && DISABLE_PWA=true bun run ../node_modules/.bin/vite build --config vite.config.docker.ts --logLevel warn && echo "✓ Frontend built") & \
    FRONTEND_PID=$!; \
    wait $BACKEND_PID || { echo "Backend build failed!"; exit 1; }; \
    wait $FRONTEND_PID || { echo "Frontend build failed!"; exit 1; }; \
    echo "✓ Parallel builds completed"

# 运行 seed
RUN bun run build:seed && echo "✓ Seed completed"

# 生成启动脚本
RUN printf '#!/bin/sh\n\
    set -e\n\
    echo "Starting Blinko..."\n\
    echo "Running database migrations..."\n\
    npx prisma migrate deploy || { echo "Migration failed!"; exit 1; }\n\
    echo "Running database seed..."\n\
    node server/seed.js || echo "Seed skipped"\n\
    echo "Starting server..."\n\
    exec node server/index.js\n' > start.sh && chmod +x start.sh


# ============================================
# Stage 3: Runner - 最终运行镜像
# ============================================
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production \
    DISABLE_SECURE_COOKIE=false \
    TRUST_PROXY=1

# 安装运行时库
RUN apk add --no-cache openssl vips-dev && \
    wget -qO /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_$(uname -m) && \
    chmod +x /usr/bin/dumb-init && \
    rm -rf /var/cache/apk/*

# 复制依赖和构建产物（按变化频率排序）
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/server/lute.min.js ./server/lute.min.js
COPY --from=builder /app/dist ./server
COPY --from=builder /app/start.sh ./start.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:1111/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

EXPOSE 1111

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/sh", "-c", "./start.sh"]
