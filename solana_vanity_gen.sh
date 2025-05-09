#!/bin/bash

# Function to display a colored message
# Usage: color_echo <color_code> "Message"
# Colors: 31=red, 32=green, 33=yellow, 34=blue, 35=magenta, 36=cyan
color_echo() {
    local color_code="$1"
    local message="$2"
    echo -e "\033[${color_code}m${message}\033[0m"
}

# --- Script Start ---
color_echo 36 "✨ Solana 靓号地址生成助手 ✨"
echo "--------------------------------------"

# 1. Check if Solana CLI is installed
if ! command -v solana &> /dev/null; then
    color_echo 31 "错误：未安装 Solana CLI 或未在您的 PATH 环境变量中找到。"
    color_echo 33 "请按照以下链接的说明进行安装：https://docs.solana.com/cli/install-solana-cli-tools"
    exit 1
fi

color_echo 32 "已找到 Solana CLI：$(solana --version)"
echo ""

# --- Interactive Questions ---
PS3="您想生成哪种类型的靓号地址？"
options=("仅前缀" "仅后缀" "同时指定前缀和后缀" "显示文章中的高级示例" "退出")
address_type=""
prefix=""
suffix=""
count=1
# Default to case-insensitive
ignore_case_flag="--ignore-case"
char_length_warning_threshold=5 # Warn if total custom chars exceed this

select opt in "${options[@]}"; do
    case $opt in
        "仅前缀")
            address_type="prefix"
            read -r -p "请输入期望的前缀 (例如, 'mywallet'): " prefix
            if [[ -z "$prefix" ]]; then
                color_echo 31 "前缀不能为空。"
                exit 1
            fi
            break
            ;;
        "仅后缀")
            address_type="suffix"
            read -r -p "请输入期望的后缀 (例如, 'node'): " suffix
            if [[ -z "$suffix" ]]; then
                color_echo 31 "后缀不能为空。"
                exit 1
            fi
            break
            ;;
        "同时指定前缀和后缀")
            address_type="both"
            read -r -p "请输入期望的前缀 (例如, 'quick'): " prefix
            if [[ -z "$prefix" ]]; then
                color_echo 31 "前缀不能为空。"
                exit 1
            fi
            read -r -p "请输入期望的后缀 (例如, 'node'): " suffix
            if [[ -z "$suffix" ]]; then
                color_echo 31 "后缀不能为空。"
                exit 1
            fi
            break
            ;;
        "显示文章中的高级示例")
            color_echo 36 "\nQuickNode 文章中的高级示例："
            color_echo 35 "此命令生成1个以 'A' 开头、以 'M' 结尾的地址（不区分大小写），"
            color_echo 35 "使用24个单词的日语助记词，不输出 .json 文件，也没有 BIP39 密码短语："
            echo ""
            color_echo 32 "solana-keygen grind --starts-and-ends-with A:M:1 --ignore-case --use-mnemonic --word-count 24 --language japanese --no-outfile --no-bip39-passphrase"
            echo ""
            color_echo 33 "注意：此脚本专注于基本的前缀/后缀生成。如果需要，您可以手动添加助记词相关选项。"
            continue # Go back to the main menu
            ;;
        "退出")
            color_echo 36 "正在退出。"
            exit 0
            ;;
        *) color_echo 31 "无效选项 $REPLY";;
    esac
done

echo ""

# Validate characters (basic reminder, not strict validation)
color_echo 33 "提醒：前缀和后缀必须使用 Base58 字符 (A-Z, a-z, 1-9)。"
color_echo 33 "不允许使用 '0' (零), 'O' (大写O), 'I' (大写I) 和 'l' (小写L) 等易混淆字符。"
echo ""

# How many addresses?
while true; do
    read -r -p "您希望用此模式生成多少个地址？ (默认: 1): " count_input
    count_input=${count_input:-1} # Default to 1 if empty
    if [[ "$count_input" =~ ^[1-9][0-9]*$ ]]; then
        count=$count_input
        break
    else
        color_echo 31 "请输入一个有效的正整数。"
    fi
done
echo ""

# Inform about default case-insensitivity
color_echo 32 "默认将进行大小写不敏感的搜索。"
echo ""

# --- Warning for long generation times ---
total_custom_chars=0
if [[ -n "$prefix" ]]; then
    total_custom_chars=$((total_custom_chars + ${#prefix}))
fi
if [[ -n "$suffix" ]]; then
    total_custom_chars=$((total_custom_chars + ${#suffix}))
fi

if (( total_custom_chars > char_length_warning_threshold )); then
    color_echo 31 "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 警告 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    color_echo 31 "您正在搜索一个包含 ${total_custom_chars} 个自定义字符的模式。"
    color_echo 31 "这可能会花费非常长的时间（数小时、数天甚至更久），并消耗大量 CPU 资源。"
    color_echo 31 "通常建议将自定义模式的字符数保持在 2-5 个。"
    color_echo 31 "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -r -p "您确定要继续吗？ (y/N): " confirm_long_search
    if [[ ! "$confirm_long_search" =~ ^[Yy]$ ]]; then
        color_echo 36 "用户已中止操作。"
        exit 0
    fi
    echo ""
fi

# --- Construct the command ---
cmd="solana-keygen grind"

case $address_type in
    "prefix")
        cmd="$cmd --starts-with ${prefix}:${count}"
        ;;
    "suffix")
        cmd="$cmd --ends-with ${suffix}:${count}"
        ;;
    "both")
        cmd="$cmd --starts-and-ends-with ${prefix}:${suffix}:${count}"
        ;;
esac

# Add the ignore-case flag (now default)
cmd="$cmd $ignore_case_flag"

# --- Display command and execute ---
color_echo 36 "\n将执行以下命令："
color_echo 35 "$cmd"
echo ""

read -r -p "按 Enter键 开始生成，或按 Ctrl+C 取消..."

color_echo 32 "开始生成... 您可以随时按 Ctrl+C 停止。"
echo "--------------------------------------"

# Execute the command
eval "$cmd" # Using eval here is generally safe as we've constructed the command from controlled inputs.

echo "--------------------------------------"
if [ $? -eq 0 ]; then
    color_echo 32 "生成过程已完成（或被中断）。"
    color_echo 36 "如果成功，您的密钥对文件（例如 ${prefix}...json 或 ...${suffix}.json）应该在当前目录中。"
    color_echo 33 "请务必安全备份您的密钥对文件，切勿泄露您的私钥！"
else
    color_echo 31 "生成过程失败或因错误中断。"
fi

color_echo 36 "\n有关更多高级选项（如助记词、单词数量、语言等），请参阅："
color_echo 36 "solana-keygen grind --help"
color_echo 36 "或 QuickNode 文章：https://www.quicknode.com/guides/solana-development/getting-started/how-to-create-a-custom-vanity-wallet-address-using-solana-cli"
echo ""