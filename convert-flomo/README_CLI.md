# 命令行工具

将 Flomo 笔记导出文件转换为 Blinko 导入格式的 Node.js 命令行工具。

## 安装依赖

```bash
npm install
```

## 使用方法

### 基本用法

```bash
node convert.js <Flomo ZIP文件路径> <Blinko用户名> [输出文件路径]
```

### 参数说明

- `<Flomo ZIP 文件路径>`: 从 Flomo 导出的 ZIP 文件路径（必需）
- `<Blinko 用户名>`: 你的 Blinko 用户名（必需，可在 Blinko 设置页面查看）
- `[输出文件路径]`: 输出的 .bko 文件路径（可选，默认为当前目录的 `flomo_notes.bko`）

### 示例

1. 使用默认输出路径：

```bash
node convert.js ./flomo_export.zip myusername
```

2. 指定输出路径：

```bash
node convert.js ./flomo_export.zip myusername ./output/my_notes.bko
```

3. 使用 npm script：

```bash
npm run convert -- ./flomo_export.zip myusername
```

## 功能特性

- 🔄 转换 Flomo 导出的 ZIP 文件为 `.bko` 格式
- ⏰ 保留原始笔记的创建和更新时间戳
- 🏷️ 自动为所有笔记添加 `#flomo` 标签
- 📷 支持图片附件转换
- ✍️ 保留 Markdown 格式
- 💻 命令行直接运行，无需浏览器

## 转换流程

1. 读取 Flomo 导出的 ZIP 文件
2. 解析 HTML 文件中的笔记内容
3. 将 HTML 内容转换为 Markdown 格式
4. 提取图片附件并统一转换为 PNG 格式
5. 生成符合 Blinko 格式的 JSON 数据
6. 打包为 `.bko` 文件（本质是包含特定结构的 ZIP 文件）

## BKO 格式说明

`.bko` 文件是一个 ZIP 压缩包，包含以下结构：

```
flomo_notes.bko
├── pgdump/
│   └── bak.json          # 笔记数据的 JSON 文件
└── files/
    ├── image1.png        # 图片附件
    └── image2.png
```

其中 `bak.json` 包含所有笔记的元数据和内容。

## 注意事项

- 确保 Flomo 导出的 ZIP 文件包含完整的笔记内容
- 转换过程中所有图片会被转换为 PNG 格式
- 建议在导入 Blinko 前备份数据
- 导入后需要在 Blinko 中强制重新嵌入向量数据以正常使用 AI 功能

## 故障排除

### 找不到 HTML 文件

确保导出的 ZIP 文件是从 Flomo 正确导出的，应包含一个 HTML 文件。

### 图片转换失败

部分图片可能因为格式或损坏无法转换，脚本会跳过这些图片并继续处理其他内容。

### 内存不足

如果笔记数量很多（超过几万条），可能需要增加 Node.js 的内存限制：

```bash
node --max-old-space-size=4096 convert.js ./flomo_export.zip myusername
```

## 相关项目

- [Blinko](https://github.com/jsongo/blinko): 开源的自托管个人 AI 笔记工具
- [Flomo](https://flomoapp.com): 卡片式笔记应用
