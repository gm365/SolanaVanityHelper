#!/bin/bash
set -euo pipefail

# =========================================
# Solana Vanity Address Helper (Enhanced)
# =========================================
# - Interactive and non-interactive modes
# - Strict Base58 validation
# - Case sensitivity choice (default: ignore-case)
# - Long-run estimator with confirmation and --yes bypass
# - Output directory support and end-of-run listing
# - Robust dependency checks (solana, solana-keygen)
# - SIGINT trap with clean exit codes
# - Safe command array execution (no eval)
# - --help with examples
#
# Exit codes:
# 0 success | 1 generic failure | 2 invalid input | 3 missing dependency | 130 user interrupt

# ---------- Colors and logging ----------
color_echo() {
  local color_code="$1"; shift
  local message="${*:-}"
  echo -e "\033[${color_code}m${message}\033[0m"
}
info()  { color_echo 36 "$*"; }
good()  { color_echo 32 "$*"; }
warn()  { color_echo 33 "$*"; }
err()   { color_echo 31 "$*"; }
note()  { color_echo 35 "$*"; }

# ---------- Globals / defaults ----------
ADDRESS_TYPE=""
PREFIX=""
SUFFIX=""
COUNT=1
CASE_MODE="insensitive"   # sensitive|insensitive
YES=0
DRY_RUN=0
OUT_DIR=""
CHAR_WARN_THRESHOLD=5
SHOW_HELP=0

# ---------- Traps ----------
on_int() {
  warn "已中断。若已生成部分文件，请检查输出目录或当前目录。"
  [[ -n "${marker:-}" && -f "$marker" ]] && rm -f "$marker" >/dev/null 2>&1
  exit 130
}
trap on_int INT

# ---------- Helpers ----------
usage() {
  cat <<'USAGE'
Solana 靓号地址生成助手 (svg.sh)
用法:
  ./svg.sh [选项] [-- 其它 solana-keygen grind 原生参数]

常用选项:
  --type prefix|suffix|both     选择匹配类型
  --prefix STR                  前缀 (Base58)
  --suffix STR                  后缀 (Base58)
  --count N                     需要生成的地址数量 (默认 1)
  --case sensitive|insensitive  大小写匹配模式 (默认 insensitive)
  --yes                         自动确认所有提示（危险操作请谨慎）
  --dry-run                     仅显示将执行的命令，不真正执行
  --out-dir PATH                输出目录；不存在将自动创建，并在结束后列出文件
  -h, --help                    显示此帮助

示例:
  仅前缀（不区分大小写）:
    ./svg.sh --type prefix --prefix sol --count 1

  仅后缀（区分大小写）:
    ./svg.sh --type suffix --suffix Node --case sensitive

  同时前后缀 + 输出到目录 + 预演:
    ./svg.sh --type both --prefix A --suffix Z --count 2 --out-dir ./vanity-outputs --dry-run

进阶:
  助记词、语言、词数等选项请直接追加到命令行，脚本将原样透传:
    例如: --use-mnemonic --word-count 24 --language japanese --no-bip39-passphrase
USAGE
}

is_base58() {
  local s="$1"
  [[ "$s" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]
}

pow_int() {
  local a="$1" b="$2"
  if command -v awk >/dev/null 2>&1; then
    awk -v a="$a" -v b="$b" 'BEGIN {
      res = a^b
      if (res > 1e12) printf "%.2e\n", res
      else printf "%.0f\n", res
    }'
  else
    echo "${a}^${b}"
  fi
}

estimate_and_confirm() {
  local total_chars="$1"
  if (( total_chars <= 0 )); then
    return 0
  fi
  
  if (( total_chars >= 43 )); then
    err "错误：前后缀总长度（${total_chars}）超过或接近 Solana 地址最大长度（约 44 字符），几乎无法生成。"
    exit 2
  fi

  local attempts
  attempts=$(pow_int 58 "$total_chars")
  warn "耗时评估：自定义字符总数 = ${total_chars}，理论尝试次数 ≈ ${attempts}"
  
  if (( total_chars > 8 )); then
    err "警告：字符数 ${total_chars} 过于庞大，普通计算机可能需要数十年甚至更久才能算出！"
  elif (( total_chars > CHAR_WARN_THRESHOLD )); then
    warn "字符越多计算耗时呈指数级增长，可能长时间占用设备的 CPU 算力。"
  fi

  if (( total_chars > CHAR_WARN_THRESHOLD )) && (( YES == 0 )); then
    read -r -p "确定继续吗？(y/N): " ans
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
      info "用户已取消。"
      exit 0
    fi
  fi
}

ensure_deps() {
  if ! command -v solana >/dev/null 2>&1; then
    err "未找到 solana 命令。请安装 Solana CLI:"
    warn "https://solana.com/docs/intro/installation"
    exit 3
  fi
  if ! command -v solana-keygen >/dev/null 2>&1; then
    err "未找到 solana-keygen 命令。请确认 Solana CLI 安装正确。"
    exit 3
  fi
  if ! solana-keygen grind --help >/dev/null 2>&1; then
    err "当前版本过低，不支持 grind 子命令。请升级 Solana CLI 工具。"
    warn "更新参考: agave-install update 或 solana-install update"
    exit 3
  fi
  
  local sol_ver
  sol_ver=$(solana --version)
  good "已找到 Solana CLI：${sol_ver}"
  note "💡 提示: 保持 Solana CLI 为最新版本，可以获得更好的性能与安全性。"
  info "👉 如果需要更新 (macOS/Linux):"
  info "   - 官方脚本安装: agave-install update (或 solana-install update)"
  info "   - Homebrew 安装: brew upgrade solana"
}

list_outputs_if_any() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    info "输出目录: $dir"
    # shellcheck disable=SC2012
    ls -l "$dir" 2>/dev/null || true
  fi
}

# ---------- Arg parsing ----------
# We support known flags and pass-through extras to solana-keygen
EXTRA_ARGS=()
while (( $# )); do
  case "${1:-}" in
    --type)
      ADDRESS_TYPE="${2:-}"; shift 2;;
    --prefix)
      PREFIX="${2:-}"; shift 2;;
    --suffix)
      SUFFIX="${2:-}"; shift 2;;
    --count)
      COUNT="${2:-}"; shift 2;;
    --case)
      CASE_MODE="${2:-}"; shift 2;;
    --yes)
      YES=1; shift;;
    --dry-run)
      DRY_RUN=1; shift;;
    --out-dir)
      OUT_DIR="${2:-}"; shift 2;;
    -h|--help)
      SHOW_HELP=1; shift;;
    --) # explicit separator
      shift
      while (( $# )); do EXTRA_ARGS+=("$1"); shift; done
      ;;
    -*)
      # unknown flag: pass through to solana-keygen
      EXTRA_ARGS+=("$1"); shift;;
    *)
      # positional arg: pass through as well
      EXTRA_ARGS+=("$1"); shift;;
  esac
done

if (( SHOW_HELP )); then
  usage
  exit 0
fi

info "✨ Solana 靓号地址生成助手 ✨"
echo "--------------------------------------"
warn "安全建议: 如果您准备生成大额资产的存储地址，"
warn "请考虑在断网 (Air-gapped) 的安全环境中运行，以确保私钥绝对安全。"
echo "--------------------------------------"

ensure_deps

# If non-interactive required fields are not set, fall back to interactive
interactive=0
if [[ -z "$ADDRESS_TYPE" ]]; then interactive=1; fi

if (( interactive )); then
  echo ""
  PS3="您想生成哪种类型的靓号地址？ "
  options=("仅前缀" "仅后缀" "同时指定前缀和后缀" "退出")
  select opt in "${options[@]}"; do
    case "$opt" in
      "仅前缀")
        ADDRESS_TYPE="prefix"
        while true; do
          read -r -p "请输入期望的前缀 (Base58): " PREFIX
          [[ -z "$PREFIX" ]] && { err "前缀不能为空。"; continue; }
          ! is_base58 "$PREFIX" && { err "包含非法字符 (禁止 0,O,I,l 四个字符，且只允许英文字母和数字)"; continue; }
          break
        done
        break;;
      "仅后缀")
        ADDRESS_TYPE="suffix"
        while true; do
          read -r -p "请输入期望的后缀 (Base58): " SUFFIX
          [[ -z "$SUFFIX" ]] && { err "后缀不能为空。"; continue; }
          ! is_base58 "$SUFFIX" && { err "包含非法字符 (禁止 0,O,I,l 四个字符，且只允许英文字母和数字)"; continue; }
          break
        done
        break;;
      "同时指定前缀和后缀")
        ADDRESS_TYPE="both"
        while true; do
          read -r -p "请输入期望的前缀 (Base58): " PREFIX
          [[ -z "$PREFIX" ]] && { err "前缀不能为空。"; continue; }
          ! is_base58 "$PREFIX" && { err "包含非法字符 (禁止 0,O,I,l 四个字符，且只允许英文字母和数字)"; continue; }
          break
        done
        while true; do
          read -r -p "请输入期望的后缀 (Base58): " SUFFIX
          [[ -z "$SUFFIX" ]] && { err "后缀不能为空。"; continue; }
          ! is_base58 "$SUFFIX" && { err "包含非法字符 (禁止 0,O,I,l 四个字符，且只允许英文字母和数字)"; continue; }
          break
        done
        break;;
      "退出")
        info "正在退出。"; echo ""; exit 0;;
      *)
        err "无效选项 $REPLY";;
    esac
  done
  echo ""
  # Case prompt
  echo "选择大小写匹配方式:"
  echo "  1) 不区分大小写 (默认)"
  echo "  2) 区分大小写"
  read -r -p "请输入序号 [1/2]: " case_sel
  case_sel=${case_sel:-1}
  if [[ "$case_sel" == "2" ]]; then CASE_MODE="sensitive"; else CASE_MODE="insensitive"; fi
  echo ""
  # Count prompt
  while true; do
    read -r -p "您希望生成多少个地址？ (默认: 1): " count_input
    count_input=${count_input:-1}
    if [[ "$count_input" =~ ^[1-9][0-9]*$ ]]; then
      COUNT="$count_input"; break
    else
      err "请输入一个有效的正整数。"
    fi
  done
  echo ""
fi

# ---------- Validation ----------
case "$ADDRESS_TYPE" in
  prefix) [[ -z "$PREFIX" ]] && { err "必须提供 --prefix"; exit 2; } ;;
  suffix) [[ -z "$SUFFIX" ]] && { err "必须提供 --suffix"; exit 2; } ;;
  both)   [[ -z "$PREFIX" || -z "$SUFFIX" ]] && { err "必须同时提供 --prefix 与 --suffix"; exit 2; } ;;
  *)      err "无效的 --type，必须为 prefix|suffix|both"; exit 2;;
esac

if ! [[ "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
  err "--count 必须为正整数"; exit 2
fi

if [[ -n "$PREFIX" ]] && ! is_base58 "$PREFIX"; then
  err "前缀不是有效的 Base58 字符串（禁止 0,O,I,l 等）。"; exit 2
fi
if [[ -n "$SUFFIX" ]] && ! is_base58 "$SUFFIX"; then
  err "后缀不是有效的 Base58 字符串（禁止 0,O,I,l 等）。"; exit 2
fi

# ---------- Estimator ----------
total_chars=0
(( ${#PREFIX} > 0 )) && total_chars=$(( total_chars + ${#PREFIX} ))
(( ${#SUFFIX} > 0 )) && total_chars=$(( total_chars + ${#SUFFIX} ))
if [[ "$CASE_MODE" == "sensitive" ]]; then
  warn "您选择了区分大小写，难度可能更高（取决于大小写分布）。"
fi
estimate_and_confirm "$total_chars"

# ---------- Prepare out dir ----------
if [[ -n "$OUT_DIR" ]]; then
  # 安全增强：创建目录时限定权限为 700，仅所有者可读写执行
  mkdir -m 700 -p "$OUT_DIR"
fi

# ---------- Build command (array, safe) ----------
cmd=( "solana-keygen" "grind" )
case "$ADDRESS_TYPE" in
  prefix) cmd+=( "--starts-with" "${PREFIX}:${COUNT}" );;
  suffix) cmd+=( "--ends-with" "${SUFFIX}:${COUNT}" );;
  both)   cmd+=( "--starts-and-ends-with" "${PREFIX}:${SUFFIX}:${COUNT}" );;
esac
if [[ "$CASE_MODE" == "insensitive" ]]; then
  cmd+=( "--ignore-case" )
fi

# Pass-through extra args (e.g., mnemonic options)
if (( ${#EXTRA_ARGS[@]} )); then
  cmd+=( "${EXTRA_ARGS[@]}" )
fi

# Detect explicit outfile control in EXTRA_ARGS
explicit_out_control=0
for x in "${EXTRA_ARGS[@]:-}"; do
  if [[ "$x" == "--no-outfile" || "$x" == "--outfile" ]]; then
    explicit_out_control=1
    break
  fi
done

info ""
info "将执行以下命令："
note "${cmd[*]}"
echo ""

if (( DRY_RUN )); then
  echo ""
  good "已开启 --dry-run：不执行，仅展示命令。"
  echo ""
  exit 0
fi

# Non-interactive mode: skip confirmation if --yes provided
if (( YES == 0 )) && (( interactive )); then
  echo ""
  read -r -p "按 Enter 键开始生成，或按 Ctrl+C 取消... " _dummy || true
fi

good "开始生成... 您可以随时按 Ctrl+C 停止。"
echo "--------------------------------------"

marker=$(mktemp)
set +e
"${cmd[@]}"
rc=$?
set -e

echo "--------------------------------------"
if [[ $rc -eq 0 ]]; then
  good "生成过程已完成。"
  
  # 收集新生成的 json 文件 (避免误伤已有密钥)
  generated_files=()
  while IFS= read -r -d '' f; do
    generated_files+=("$f")
  done < <(find . -maxdepth 1 -name "*.json" -type f -newer "$marker" -print0 2>/dev/null)
  rm -f "$marker" >/dev/null 2>&1 || true

  if (( ${#generated_files[@]} > 0 )); then
    # 安全增强：强制修改私钥文件及其权限
    chmod 600 "${generated_files[@]}"
    
    if (( explicit_out_control == 0 )) && [[ -n "$OUT_DIR" ]]; then
      mv -f "${generated_files[@]}" "$OUT_DIR/" >/dev/null 2>&1
      good "已将新生成的 ${#generated_files[@]} 个密钥文件安全移动到: $OUT_DIR (权限自适应设为 600)"
      list_outputs_if_any "$OUT_DIR"
    else
      good "已将新生成的 ${#generated_files[@]} 个密钥文件权限设为 600 (仅所有者可读写)。"
      if [[ -z "$OUT_DIR" ]] && (( explicit_out_control == 0 )); then
        info "新生成的密钥文件清单："
        ls -l "${generated_files[@]}" 2>/dev/null || true
      fi
    fi
  else
    warn "未检测到在当前目录下新生成 .json 文件。"
    if (( explicit_out_control == 1 )); then
      info "可能您指定了额外的路径参数 (--outfile 等)，请自行确认生成结果和文件权限！"
    fi
  fi

  warn "请务必安全备份您的密钥对文件，切勿将私钥泄露给任何人！"
  exit 0
else
  rm -f "$marker" >/dev/null 2>&1 || true
  err "生成过程失败或中断 (exit $rc)。"
  exit "$rc"
fi

# References:
#   solana-keygen grind --help
#   QuickNode 教程: https://www.quicknode.com/guides/solana-development/getting-started/how-to-create-a-custom-vanity-wallet-address-using-solana-cli
