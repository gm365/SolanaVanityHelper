# Solana 靓号地址生成助手 (Solana Vanity Address Generator Helper)

本脚本基于 Solana 官方 `solana-keygen grind`，提供中文交互与非交互两种模式，支持严格 Base58 校验、大小写匹配选择、长耗时估算（58^n 提示）、输出目录整理、依赖检查、SIGINT 安全中断、无 eval 的安全执行。适合初学者和进阶用户。

脚本入口：[`bash.read`](solana_vanity_gen.sh:1)

## ✨ 功能特性（已增强）
- 中文交互界面与非交互 CLI 参数
- 模式选择：仅前缀 / 仅后缀 / 前后缀同时指定
- 自定义生成数量 (--count)
- 大小写匹配：不区分（默认）/ 区分 (--case)
- 严格 Base58 校验（拒绝 0 O I l）
- 长耗时估算与确认（可用 --yes 跳过）
- 输出目录 (--out-dir) 与运行结束文件清单
- 依赖检查：solana, solana-keygen, grind 可用性
- SIGINT 捕获与统一退出码
- 命令预览与 --dry-run 预演
- 透传原生参数（助记词、语言、词数等）

## ⚠️ 安全与隐私
- 本脚本调用本地 `solana-keygen grind` 生成密钥，不上传网络。
- 生成的 .json 私钥文件需自行妥善保存，建议权限：`chmod 600 file.json`。
- 大量字符匹配可能耗时很久并持续占用 CPU，请谨慎设置参数。

## 🚀 环境要求
- Bash (Linux / macOS / WSL)
- [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools)

## 🛠️ 安装与快速开始
1) 赋予执行权限
```bash
chmod +x ./solana_vanity_gen.sh
```
2) 交互模式运行
```bash
./solana_vanity_gen.sh
```

## 🤖 非交互命令行用法
脚本支持以下常用参数；其它原生参数使用 `--` 分隔后透传至 `solana-keygen grind`。

常用参数
- --type prefix|suffix|both
- --prefix STR
- --suffix STR
- --count N
- --case sensitive|insensitive  (默认 insensitive)
- --yes                         自动确认
- --dry-run                     仅展示命令不执行
- --out-dir PATH                将生成的 .json 归档到目录
- -h, --help                    显示帮助

示例
- 不区分大小写的前缀:
```bash
./solana_vanity_gen.sh --type prefix --prefix sol --count 1
```
- 区分大小写的后缀:
```bash
./solana_vanity_gen.sh --type suffix --suffix Node --case sensitive
```
- 前后缀同时匹配 + 输出目录:
```bash
./solana_vanity_gen.sh --type both --prefix A --suffix Z --count 2 --out-dir ./vanity-outputs
```
- 预演（不执行）:
```bash
./solana_vanity_gen.sh --type prefix --prefix gm --dry-run
```
- 透传原生参数（助记词示例）:
```bash
./solana_vanity_gen.sh --type prefix --prefix A --count 1 -- --use-mnemonic --word-count 24 --language japanese --no-bip39-passphrase
```

## 📈 耗时估算
- 估算公式：期望尝试次数 ≈ 58^(前缀长度 + 后缀长度)。
- 当自定义字符总数超过阈值（默认 5）时会提示确认，可用 `--yes` 跳过。

## 📂 输出与文件组织
- 未指定 `--out-dir` 时，`solana-keygen` 默认在当前目录生成 .json。
- 指定 `--out-dir` 时，脚本会在任务结束后将当前目录下生成的 .json 移动到该目录，并打印清单。
- 也可透传原生 `--no-outfile` 或 `--outfile` 完全自行控制输出。

## 💡 进阶
- 查看帮助：
```bash
./solana_vanity_gen.sh --help
```
- 原生命令帮助：
```bash
solana-keygen grind --help
```
- 参考教程：QuickNode 指南（包含助记词、语言、词数等）

## 🖼️ 使用方法演示截图
![前缀5888](/images/前缀5888.avif)
**上图为生成前缀 5888 地址的演示图**

![后缀pump](/images/后缀pump.avif)
**上图为生成后缀 pump 地址的演示图**

## 🤝 贡献
欢迎提交 Issues / PR 改进此脚本。

## 📄 许可证
本项目采用 MIT 许可证，详见 LICENSE。

## 联系方式
- GitHub: [@gm365](https://github.com/gm365)
- Twitter: [@gm365](https://x.com/gm365)
