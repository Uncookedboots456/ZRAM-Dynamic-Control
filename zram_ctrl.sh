#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_conf() {
    local key value
    key="$1"
    value=$(grep "^${key}=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r\n ')
    echo "$value"
}

read_mem_total_kb() {
    local kb
    kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
    case "$kb" in
        ''|*[!0-9]*) kb=1024 ;;
    esac
    if [ "$kb" -le 0 ] 2>/dev/null; then
        kb=1024
    fi
    echo "$kb"
}

format_gb_from_kb() {
    awk -v kb="$1" 'BEGIN {printf "%.2f", kb / 1024 / 1024}'
}

is_positive_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -gt 0 ] 2>/dev/null ;;
    esac
}

is_non_negative_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

notify_result() {
    local title text
    title="$1"
    text="$2"
    if command -v cmd >/dev/null 2>&1; then
        cmd notification post -t "$title" zram_dynamic_control "$text" >/dev/null 2>&1
    fi
}

fail() {
    local code message
    code="$1"
    message="$2"
    echo "$message"
    notify_result "ZRAM 生效失败" "$message"
    exit "$code"
}

read_target_zram_kb() {
    local kb gb
    kb=$(read_conf ZRAM_SIZE_KB)
    if is_positive_integer "$kb"; then
        echo "$kb"
        return
    fi
    gb=$(read_conf ZRAM_SIZE_GB)
    if is_positive_integer "$gb"; then
        awk -v gb="$gb" 'BEGIN {printf "%d", gb * 1024 * 1024}'
        return
    fi
    echo "0"
}

if [ ! -f "$CONF" ]; then
    fail 11 "[x] 配置文件不存在: $CONF"
fi

ENABLED=$(read_conf ENABLED)
ZRAM_SIZE_KB=$(read_target_zram_kb)
COMP_ALGORITHM=$(read_conf COMP_ALGORITHM)
SWAPPINESS=$(read_conf SWAPPINESS)
WATERMARK_SCALE=$(read_conf WATERMARK_SCALE_FACTOR)
MEM_TOTAL_KB=$(read_mem_total_kb)
MEM_TOTAL_GB=$(format_gb_from_kb "$MEM_TOTAL_KB")
TARGET_ZRAM_GB=$(format_gb_from_kb "$ZRAM_SIZE_KB")

ENABLED=${ENABLED:-0}
ZRAM_SIZE_KB=${ZRAM_SIZE_KB:-0}
COMP_ALGORITHM=${COMP_ALGORITHM:-lz4}
SWAPPINESS=${SWAPPINESS:-80}
WATERMARK_SCALE=${WATERMARK_SCALE:-50}

if [ "$ENABLED" != "1" ]; then
    echo "[!] 当前配置未启用，请先在 WebUI 保存并立即执行。"
    exit 10
fi

if ! is_positive_integer "$ZRAM_SIZE_KB"; then
    fail 12 "[x] ZRAM_SIZE_KB 必须是正整数。"
fi

if [ "$ZRAM_SIZE_KB" -gt "$MEM_TOTAL_KB" ] 2>/dev/null; then
    fail 13 "[x] 目标 ZRAM ${ZRAM_SIZE_KB}KB 超过物理内存上限 ${MEM_TOTAL_KB}KB。"
fi

case "$COMP_ALGORITHM" in
    lz4|zstd) ;;
    *) fail 14 "[x] 不支持的压缩算法: $COMP_ALGORITHM" ;;
esac

if ! is_non_negative_integer "$SWAPPINESS" || [ "$SWAPPINESS" -gt 200 ] 2>/dev/null; then
    fail 15 "[x] SWAPPINESS 必须是 0 到 200 之间的整数。"
fi

if ! is_positive_integer "$WATERMARK_SCALE"; then
    fail 16 "[x] WATERMARK_SCALE_FACTOR 必须是正整数。"
fi

echo "[*] 开始执行 ZRAM 核心引擎..."
echo "[*] 物理内存上限: ${MEM_TOTAL_KB}KB (~${MEM_TOTAL_GB}GB)"
echo "[*] 目标配置: ${ZRAM_SIZE_KB}KB (~${TARGET_ZRAM_GB}GB) | ${COMP_ALGORITHM} | Swap:${SWAPPINESS} | WM:${WATERMARK_SCALE}"

if [ ! -w /sys/block/zram0/disksize ] || [ ! -w /sys/block/zram0/comp_algorithm ]; then
    fail 17 "[x] ZRAM sysfs 节点不可写。"
fi

sync
if ! echo 3 > /proc/sys/vm/drop_caches; then
    fail 18 "[x] drop_caches 写入失败。"
fi

echo "[*] 正在卸载旧节点..."
if grep -q '^/dev/block/zram0 ' /proc/swaps 2>/dev/null; then
    if ! swapoff /dev/block/zram0; then
        fail 19 "[x] swapoff 执行失败。"
    fi
else
    echo "[*] 检测到当前未启用 zram swap，跳过 swapoff。"
fi
if ! echo 1 > /sys/block/zram0/reset; then
    fail 20 "[x] zram reset 失败。"
fi

echo "[*] 正在重新分配空间与协议..."
if ! echo "$COMP_ALGORITHM" > /sys/block/zram0/comp_algorithm; then
    fail 21 "[x] 压缩算法写入失败。"
fi
ZRAM_BYTES=$(awk -v kb="$ZRAM_SIZE_KB" 'BEGIN {printf "%d", kb * 1024}')
if ! echo "$ZRAM_BYTES" > /sys/block/zram0/disksize; then
    fail 22 "[x] disksize 写入失败。"
fi

echo "[*] 挂载新 ZRAM..."
if ! mkswap /dev/block/zram0; then
    fail 23 "[x] mkswap 执行失败。"
fi
if ! swapon /dev/block/zram0; then
    fail 24 "[x] swapon 执行失败。"
fi

echo "[*] 注入内核调优参数..."
if ! echo "$SWAPPINESS" > /proc/sys/vm/swappiness; then
    fail 25 "[x] swappiness 写入失败。"
fi
if ! echo "$WATERMARK_SCALE" > /proc/sys/vm/watermark_scale_factor; then
    fail 26 "[x] watermark_scale_factor 写入失败。"
fi

echo "[√] 所有底层操作已完成。"
notify_result "ZRAM 已生效" "${ZRAM_SIZE_KB}KB (~${TARGET_ZRAM_GB}GB) / ${COMP_ALGORITHM} 已成功生效"
exit 0