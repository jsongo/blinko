import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from 'path';
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

const host = process.env.TAURI_DEV_HOST || '0.0.0.0';
const EXPRESS_PORT = 1111;

// Docker 构建专用配置 - 优化速度
// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    ...(!process.env.DISABLE_PWA ? [
      VitePWA({
        devOptions: {
          enabled: false
        },
        injectRegister: 'auto',
        registerType: 'autoUpdate',
        includeAssets: ['icons/Square*.png'],
        manifest: {
          name: 'Blinko',
          short_name: 'Blinko',
          icons: [
            {
              src: '/icons/Square30x30Logo.png',
              sizes: '30x30',
              type: 'image/png'
            },
            {
              src: '/icons/Square44x44Logo.png',
              sizes: '44x44',
              type: 'image/png'
            },
            {
              src: '/icons/Square71x71Logo.png',
              sizes: '71x71',
              type: 'image/png'
            },
            {
              src: '/icons/Square89x89Logo.png',
              sizes: '89x89',
              type: 'image/png'
            },
            {
              src: '/icons/Square107x107Logo.png',
              sizes: '107x107',
              type: 'image/png'
            },
            {
              src: '/icons/Square142x142Logo.png',
              sizes: '142x142',
              type: 'image/png'
            },
            {
              src: '/icons/Square150x150Logo.png',
              sizes: '150x150',
              type: 'image/png'
            },
            {
              src: '/icons/Square284x284Logo.png',
              sizes: '284x284',
              type: 'image/png'
            },
            {
              src: '/icons/Square310x310Logo.png',
              sizes: '310x310',
              type: 'image/png',
              purpose: 'any maskable'
            }
          ],
          theme_color: '#FFFFFF',
          background_color: '#FFFFFF',
          start_url: '/',
          display: 'standalone',
          orientation: 'portrait'
        },
        workbox: {
          maximumFileSizeToCacheInBytes: 10 * 1024 * 1024,
          navigateFallbackDenylist: [/^\/api\/.*/],
        }
      })
    ] : [])
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@shared': path.resolve(__dirname, '../shared')
    }
  },
  build: {
    outDir: "../dist/public",
    emptyOutDir: true,
    chunkSizeWarningLimit: 2000,
    // Docker 构建优化: 简化 rollup 配置
    rollupOptions: {
      external: ['tauri-plugin-blinko-api'],
      output: {
        // 使用简单的 chunk 策略,避免复杂的路径匹配
        manualChunks: undefined  // 让 Vite 自动处理,更快!
      },
      // 增加并行度 - GitHub Actions 有 4 核心
      maxParallelFileOps: 4,  // 默认 20,在 QEMU 中减少以避免上下文切换
    },
    // 跳过不必要的操作
    reportCompressedSize: false,  // 跳过 gzip 大小计算
    minify: 'esbuild',  // esbuild 比 terser 快
    // esbuild 优化
    target: 'es2020',  // 现代浏览器,减少转换
  },
  esbuild: {
    // 禁用 legal comments 以加速
    legalComments: 'none',
    // 减少 minify 的工作量
    minifyIdentifiers: true,
    minifySyntax: true,
    minifyWhitespace: true,
  },
  clearScreen: false,
  server: {
    port: 5173,
    strictPort: false,
    host: host || false,
    allowedHosts: true,
    hmr: {
      overlay: false
    },
    watch: {
      ignored: ["**/src-tauri/**", "**/node_modules/**", "**/.git/**"],
    },
  },
  optimizeDeps: {
    force: false,
    include: ['react', 'react-dom', 'react-router-dom'],
    exclude: []
  },
  css: {
    devSourcemap: false
  },
  cacheDir: 'node_modules/.vite',
  experimental: {
    renderBuiltUrl: (filename) => ({ relative: true }),
  },
  // Docker 构建优化
  logLevel: 'info',  // 输出更多日志,方便调试
});
