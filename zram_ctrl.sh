#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_conf() {
    local key value
    key="$1"
    value=$(grep "^${key}=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r\n ')
    echo "$value"
}

read_mem_total_mb() {
    local kb mb
    kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
    case "$kb" in
        ''|*[!0-9]*) kb=1024 ;;
    esac
    if [ "$kb" -le 0 ] 2>/dev/null; then
        kb=1024
    fi
    mb=$(awk -v kb="$kb" 'BEGIN {printf "%d", kb / 1024}')
    if [ -z "$mb" ] || [ "$mb" -lt 1 ] 2>/dev/null; then
        mb=1
    fi
    echo "$mb"
}

format_gb_from_mb() {
    awk -v mb="$1" 'BEGIN {printf "%.2f", mb / 1024}'
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

read_target_zram_mb() {
    local mb kb gb
    mb=$(read_conf ZRAM_SIZE_MB)
    if is_positive_integer "$mb"; then
        echo "$mb"
        return
    fi
    kb=$(read_conf ZRAM_SIZE_KB)
    if is_positive_integer "$kb"; then
        awk -v kb="$kb" 'BEGIN {printf "%d", kb / 1024}'
        return
    fi
    gb=$(read_conf ZRAM_SIZE_GB)
    if is_positive_integer "$gb"; then
        awk -v gb="$gb" 'BEGIN {printf "%d", gb * 1024}'
        return
    fi
    echo "0"
}

if [ ! -f "$CONF" ]; then
    fail 11 "[x] 配置文件不存在: $CONF"
fi

ENABLED=$(read_conf ENABLED)
ZRAM_SIZE_MB=$(read_target_zram_mb)
COMP_ALGORITHM=$(read_conf COMP_ALGORITHM)
SWAPPINESS=$(read_conf SWAPPINESS)
WATERMARK_SCALE=$(read_conf WATERMARK_SCALE_FACTOR)
MEM_TOTAL_MB=$(read_mem_total_mb)
MEM_TOTAL_GB=$(format_gb_from_mb "$MEM_TOTAL_MB")
TARGET_ZRAM_GB=$(format_gb_from_mb "$ZRAM_SIZE_MB")

ENABLED=${ENABLED:-0}
ZRAM_SIZE_MB=${ZRAM_SIZE_MB:-0}
COMP_ALGORITHM=${COMP_ALGORITHM:-lz4}
SWAPPINESS=${SWAPPINESS:-80}
WATERMARK_SCALE=${WATERMARK_SCALE:-50}

if [ "$ENABLED" != "1" ]; then
    echo "[!] 当前配置未启用，请先在 WebUI 保存并立即执行。"
    exit 10
fi

if ! is_positive_integer "$ZRAM_SIZE_MB"; then
    fail 12 "[x] ZRAM_SIZE_MB 必须是正整数。"
fi

if [ "$ZRAM_SIZE_MB" -gt "$MEM_TOTAL_MB" ] 2>/dev/null; then
    fail 13 "[x] 目标 ZRAM ${ZRAM_SIZE_MB}MB 超过物理内存上限 ${MEM_TOTAL_MB}MB。"
fi

case "$COMP_ALGORITHM" in
    lz4|zstd|lzo|lzo-rle|lz4hc|842|zstd-fast) ;;
    *) fail 14 "[x] 不支持的压缩算法: $COMP_ALGORITHM" ;;
esac

if ! is_non_negative_integer "$SWAPPINESS" || [ "$SWAPPINESS" -gt 200 ] 2>/dev/null; then
    fail 15 "[x] SWAPPINESS 必须是 0 到 200 之间的整数。"
fi

if ! is_positive_integer "$WATERMARK_SCALE"; then
    fail 16 "[x] WATERMARK_SCALE_FACTOR 必须是正整数。"
fi

echo "[*] 开始执行 ZRAM 核心引擎..."
echo "[*] 物理内存上限: ${MEM_TOTAL_MB}MB (~${MEM_TOTAL_GB}GB)"
echo "[*] 目标配置: ${ZRAM_SIZE_MB}MB (~${TARGET_ZRAM_GB}GB) | ${COMP_ALGORITHM} | Swap:${SWAPPINESS} | WM:${WATERMARK_SCALE}"

if [ ! -w /sys/block/zram0/disksize ] || [ ! -w /sys/block/zram0/comp_algorithm ]; then
    fail 17 "[x] ZRAM sysfs 节点不可写。"
fi

SWAPPINESS_BAK=$(cat /proc/sys/vm/swappiness 2>/dev/null)
SWAPPINESS_BAK=${SWAPPINESS_BAK:-60}

if ! echo 4 > /sys/block/zram0/max_comp_streams; then
    fail 18 "[x] max_comp_streams 写入失败。"
fi
if ! sync; then
    fail 19 "[x] sync 执行失败。"
fi

BACKING_DEV=""
if [ -f /sys/block/zram0/backing_dev ]; then
    BACKING_DEV=$(cat /sys/block/zram0/backing_dev 2>/dev/null)
fi

if [ -n "$1" ] && [ "$1" = "boot" ]; then
    if ! echo 0 > /proc/sys/vm/swappiness; then
        fail 20 "[x] 开机路径临时写入 swappiness=0 失败。"
    fi
fi

if ! echo 3 > /proc/sys/vm/drop_caches; then
    fail 21 "[x] drop_caches 写入失败。"
fi

echo "[*] 正在卸载旧节点..."
if grep -q '^/dev/block/zram0 ' /proc/swaps 2>/dev/null; then
    if ! swapoff /dev/block/zram0 >/dev/null 2>&1; then
        fail 22 "[x] swapoff 执行失败。"
    fi
else
    echo "[*] 检测到当前未启用 zram swap，跳过 swapoff。"
fi
if ! echo 1 > /sys/block/zram0/reset; then
    fail 23 "[x] zram reset 失败。"
fi

if [ -f /sys/block/zram0/backing_dev ] && [ -n "$BACKING_DEV" ]; then
    if ! printf '%s' "$BACKING_DEV" > /sys/block/zram0/backing_dev; then
        fail 24 "[x] backing_dev 写回失败。"
    fi
fi

echo "[*] 正在重新分配空间与协议..."
if ! printf '%s' "$COMP_ALGORITHM" > /sys/block/zram0/comp_algorithm; then
    fail 25 "[x] 压缩算法写入失败。"
fi
if ! echo 4 > /sys/block/zram0/max_comp_streams; then
    fail 26 "[x] max_comp_streams 重新写入失败。"
fi
if [ "$ZRAM_SIZE_MB" -gt 2047 ] 2>/dev/null; then
    if ! printf '%sM' "$ZRAM_SIZE_MB" > /sys/block/zram0/disksize; then
        fail 27 "[x] 以 M 单位写入 disksize 失败。"
    fi
else
    ZRAM_BYTES=$(awk -v mb="$ZRAM_SIZE_MB" 'BEGIN {printf "%d", mb * 1024 * 1024}')
    if ! printf '%s' "$ZRAM_BYTES" > /sys/block/zram0/disksize; then
        fail 28 "[x] 以字节写入 disksize 失败。"
    fi
fi

echo "[*] 挂载新 ZRAM..."
if ! mkswap /dev/block/zram0 >/dev/null 2>&1; then
    fail 29 "[x] mkswap 执行失败。"
fi
if ! swapon /dev/block/zram0 -p 0 >/dev/null 2>&1; then
    fail 30 "[x] swapon 执行失败。"
fi

echo "[*] 注入内核调优参数..."
if ! echo "$SWAPPINESS" > /proc/sys/vm/swappiness; then
    fail 31 "[x] swappiness 写入失败。"
fi
if ! echo "$WATERMARK_SCALE" > /proc/sys/vm/watermark_scale_factor; then
    fail 32 "[x] watermark_scale_factor 写入失败。"
fi

echo "[√] 所有底层操作已完成。"
notify_result "ZRAM 已生效" "${ZRAM_SIZE_MB}MB (~${TARGET_ZRAM_GB}GB) / ${COMP_ALGORITHM} 已成功生效"
exit 0