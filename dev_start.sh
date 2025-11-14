#!/bin/bash

# 终端 1 - 启动后端 API
bun dev:backend &

# 终端 2 - 启动前端（使用 Node.js 运行 Vite）
bun dev:frontend &