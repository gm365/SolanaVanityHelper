# Solana 靓号地址生成助手 (SVG - Solana Vanity Generator)

本脚本基于 Solana 官方 `solana-keygen grind`，提供简洁高效的靓号地址生成功能。经过深度强化，现已具备严格字符校验、自动化权限防护、版本智能升级指引以及防溢出的高精度耗时估算。

脚本名称：[`svg.sh`](file:///Users/sos/Documents/GitHub/SolanaVanityHelper/svg.sh)

## ✨ 主要特性
- **极简命令**：重命名为 `svg.sh`，更易输入和记忆。
- **强制安全性**：生成的私钥强制 `chmod 600`，输出目录强制 `chmod 700`。
- **智能交互**：更清爽的菜单排版，支持输入非法 Base58 字符时即时纠错并重试。
- **版本指引**：启动检测 `Solana CLI` 状态，并为 macOS 提供一键升级指引。
- **高精度估算**：采用 `awk` 解决大位数运算溢出，提供真实的尝试次数预估。
- **归档支持**：支持 `--out-dir` 归档并自动识别新生成文件（不误触旧密钥）。

## ⚠️ 安全警告
- **物理断网**：生成大额资产地址时，强烈建议在**物理断网**环境下运行。
- **权限管理**：脚本自动保障私钥文件权限，请勿手动将私钥暴露给他人。
- **零联网**：核心生成逻辑 100% 运行于本地。

## ⚡️ 快速开始
1) **赋予执行权限**
```bash
chmod +x ./svg.sh
```
2) **交互模式运行**
```bash
./svg.sh
```

## 🛠️ 参数说明 (CLI 模式)
除了以下参数外，可通过 `--` 后传递任何 `solana-keygen grind` 的原生参数。

| 参数 | 说明 |
| :--- | :--- |
| `--type` | `prefix` / `suffix` / `both` |
| `--prefix` | 指定前缀 (Base58) |
| `--suffix` | 指定后缀 (Base58) |
| `--count` | 生成数量（默认 1） |
| `--case` | `sensitive` / `insensitive` (默认) |
| `--out-dir` | 指定归档输出文件夹 |
| `--yes` | 自动确认长耗时提醒 |
| `--dry-run` | 仅展示生成的原始命令 |

### 使用示例
```bash
# 生成 1 个以 gm 开头的地址
./svg.sh --type prefix --prefix gm

# 同时匹配前后缀，并存入指定文件夹
./svg.sh --type both --prefix A --suffix Z --out-dir ./wallets

# 使用 24 位助记词模式生成地址
./svg.sh --type prefix --prefix Hi -- --use-mnemonic --word-count 24
```

## 🛠️ 环境配置
- **操作系统**：macOS / Linux / WSL (Bash)
- **核心组件**：[Solana CLI](https://solana.com/docs/intro/installation)
  - 升级命令 (macOS): `agave-install update` 或 `brew upgrade solana`

---
**联系方式**
- GitHub: [@gm365](https://github.com/gm365)
- Twitter: [@gm365](https://x.com/gm365)
