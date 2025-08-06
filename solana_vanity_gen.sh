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
  exit 130
}
trap on_int INT

# ---------- Helpers ----------
usage() {
  cat <<'USAGE'
Solana 靓号地址生成助手 (增强版)
用法:
  ./solana_vanity_gen.sh [选项] [-- 其它 solana-keygen grind 原生参数]

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
    ./solana_vanity_gen.sh --type prefix --prefix sol --count 1

  仅后缀（区分大小写）:
    ./solana_vanity_gen.sh --type suffix --suffix Node --case sensitive

  同时前后缀 + 输出到目录 + 预演:
    ./solana_vanity_gen.sh --type both --prefix A --suffix Z --count 2 --out-dir ./vanity-outputs --dry-run

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
  # compute a^b (integers)
  local a="$1" b="$2" result=1
  while (( b > 0 )); do
    result=$(( result * a ))
    b=$(( b - 1 ))
  done
  echo "$result"
}

estimate_and_confirm() {
  local total_chars="$1"
  if (( total_chars <= 0 )); then
    return 0
  fi
  # Expected attempts ~ 58^n
  local attempts
  attempts=$(pow_int 58 "$total_chars")
  warn "耗时提醒：自定义字符总数 = ${total_chars}，理论尝试次数 ≈ 58^${total_chars} = ${attempts}"
  warn "字符越多，耗时指数级增长，可能长时间占用 CPU。建议控制在 2-5 个字符。"
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
    warn "https://docs.solana.com/cli/install-solana-cli-tools"
    exit 3
  fi
  if ! command -v solana-keygen >/dev/null 2>&1; then
    err "未找到 solana-keygen 命令。请确认 Solana CLI 安装正确。"
    exit 3
  fi
  if ! solana-keygen grind --help >/dev/null 2>&1; then
    err "solana-keygen 不支持 grind 子命令或执行失败。请升级 Solana 工具。"
    exit 3
  fi
  good "已找到 Solana CLI：$(solana --version)"
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

ensure_deps

# If non-interactive required fields are not set, fall back to interactive
interactive=0
if [[ -z "$ADDRESS_TYPE" ]]; then interactive=1; fi

if (( interactive )); then
  PS3="您想生成哪种类型的靓号地址？"
  options=("仅前缀" "仅后缀" "同时指定前缀和后缀" "显示文章中的高级示例" "退出")
  select opt in "${options[@]}"; do
    case "$opt" in
      "仅前缀")
        ADDRESS_TYPE="prefix"
        read -r -p "请输入期望的前缀 (Base58): " PREFIX
        [[ -z "$PREFIX" ]] && { err "前缀不能为空。"; exit 2; }
        break;;
      "仅后缀")
        ADDRESS_TYPE="suffix"
        read -r -p "请输入期望的后缀 (Base58): " SUFFIX
        [[ -z "$SUFFIX" ]] && { err "后缀不能为空。"; exit 2; }
        break;;
      "同时指定前缀和后缀")
        ADDRESS_TYPE="both"
        read -r -p "请输入期望的前缀 (Base58): " PREFIX
        [[ -z "$PREFIX" ]] && { err "前缀不能为空。"; exit 2; }
        read -r -p "请输入期望的后缀 (Base58): " SUFFIX
        [[ -z "$SUFFIX" ]] && { err "后缀不能为空。"; exit 2; }
        break;;
      "显示文章中的高级示例")
        info ""
        info "QuickNode 文章中的高级示例："
        note "生成1个以 'A' 开头、以 'M' 结尾的地址（不区分大小写），"
        note "使用24个单词的日语助记词，不输出 .json 文件，也没有 BIP39 密码短语："
        echo ""
        good "solana-keygen grind --starts-and-ends-with A:M:1 --ignore-case --use-mnemonic --word-count 24 --language japanese --no-bip39-passphrase"
        echo ""
        warn "注意：本脚本聚焦前/后缀。助记词相关参数可在本脚本后追加传入。"
        continue;;
      "退出")
        info "正在退出。"; exit 0;;
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
  mkdir -p "$OUT_DIR"
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
  good "已开启 --dry-run：不执行，仅展示命令。"
  exit 0
fi

# Non-interactive mode: skip confirmation if --yes provided
if (( YES == 0 )) && (( interactive )); then
  read -r -p "按 Enter 键开始生成，或按 Ctrl+C 取消... " _dummy || true
fi

good "开始生成... 您可以随时按 Ctrl+C 停止。"
echo "--------------------------------------"

set +e
"${cmd[@]}"
rc=$?
set -e

echo "--------------------------------------"
if [[ $rc -eq 0 ]]; then
  good "生成过程已完成。"
  if (( explicit_out_control == 0 )); then
    # Move any generated *.json into OUT_DIR if provided
    if [[ -n "$OUT_DIR" ]]; then
      shopt -s nullglob
      moved=0
      for f in ./*.json; do
        mv -f "$f" "$OUT_DIR/" >/dev/null 2>&1 && moved=1
      done
      shopt -u nullglob
      if (( moved )); then
        good "已将生成的 .json 文件移动到: $OUT_DIR"
      fi
    fi
  fi
  if [[ -n "$OUT_DIR" ]]; then
    list_outputs_if_any "$OUT_DIR"
  else
    info "若成功生成，.json 文件应位于当前目录。"
  fi
  warn "请务必安全备份您的密钥对文件，切勿泄露私钥。建议设置权限: chmod 600 <文件.json>"
  exit 0
else
  err "生成过程失败或中断 (exit $rc)。"
  exit "$rc"
fi

# References:
#   solana-keygen grind --help
#   QuickNode 教程: https://www.quicknode.com/guides/solana-development/getting-started/how-to-create-a-custom-vanity-wallet-address-using-solana-cli
