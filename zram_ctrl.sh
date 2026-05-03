#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_conf() {
    local key value
    key="$1"
    value=$(grep "^${key}=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r\n ')
    echo "$value"
}

read_mem_total_gb() {
    local kb gb
    kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
    gb=$(awk -v kb="$kb" 'BEGIN {printf "%d", kb / 1024 / 1024}')
    if [ -z "$gb" ] || [ "$gb" -lt 1 ] 2>/dev/null; then
        gb=1
    fi
    echo "$gb"
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

if [ ! -f "$CONF" ]; then
    echo "[x] 配置文件不存在: $CONF"
    exit 11
fi

ENABLED=$(read_conf ENABLED)
ZRAM_SIZE_GB=$(read_conf ZRAM_SIZE_GB)
COMP_ALGORITHM=$(read_conf COMP_ALGORITHM)
SWAPPINESS=$(read_conf SWAPPINESS)
WATERMARK_SCALE=$(read_conf WATERMARK_SCALE_FACTOR)
MEM_TOTAL_GB=$(read_mem_total_gb)

ENABLED=${ENABLED:-0}
ZRAM_SIZE_GB=${ZRAM_SIZE_GB:-0}
COMP_ALGORITHM=${COMP_ALGORITHM:-lz4}
SWAPPINESS=${SWAPPINESS:-80}
WATERMARK_SCALE=${WATERMARK_SCALE:-50}

if [ "$ENABLED" != "1" ]; then
    echo "[!] 当前配置未启用，请先在 WebUI 保存配置。"
    exit 10
fi

if ! is_positive_integer "$ZRAM_SIZE_GB"; then
    echo "[x] ZRAM_SIZE_GB 必须是正整数。"
    exit 12
fi

if [ "$ZRAM_SIZE_GB" -gt "$MEM_TOTAL_GB" ] 2>/dev/null; then
    echo "[x] 目标 ZRAM 大小 ${ZRAM_SIZE_GB}GB 超过物理内存上限 ${MEM_TOTAL_GB}GB。"
    exit 13
fi

case "$COMP_ALGORITHM" in
    lz4|zstd) ;;
    *)
        echo "[x] 不支持的压缩算法: $COMP_ALGORITHM"
        exit 14
        ;;
esac

if ! is_non_negative_integer "$SWAPPINESS" || [ "$SWAPPINESS" -gt 200 ] 2>/dev/null; then
    echo "[x] SWAPPINESS 必须是 0 到 200 之间的整数。"
    exit 15
fi

if ! is_positive_integer "$WATERMARK_SCALE"; then
    echo "[x] WATERMARK_SCALE_FACTOR 必须是正整数。"
    exit 16
fi

echo "[*] 开始执行 ZRAM 核心引擎..."
echo "[*] 物理内存上限: ${MEM_TOTAL_GB}GB"
echo "[*] 目标配置: ${ZRAM_SIZE_GB}GB | ${COMP_ALGORITHM} | Swap:${SWAPPINESS} | WM:${WATERMARK_SCALE}"

if [ ! -w /sys/block/zram0/disksize ] || [ ! -w /sys/block/zram0/comp_algorithm ]; then
    echo "[x] ZRAM sysfs 节点不可写。"
    exit 17
fi

# 释放缓存
sync
if ! echo 3 > /proc/sys/vm/drop_caches; then
    echo "[x] drop_caches 写入失败。"
    exit 18
fi

# 卸载现有 ZRAM
echo "[*] 正在卸载旧节点..."
if grep -q '^/dev/block/zram0 ' /proc/swaps 2>/dev/null; then
    if ! swapoff /dev/block/zram0; then
        echo "[x] swapoff 执行失败。"
        exit 19
    fi
else
    echo "[*] 检测到当前未启用 zram swap，跳过 swapoff。"
fi
if ! echo 1 > /sys/block/zram0/reset; then
    echo "[x] zram reset 失败。"
    exit 20
fi

# 下发底层协议与容量 (awk 防止溢出变0)
echo "[*] 正在重新分配空间与协议..."
if ! echo "$COMP_ALGORITHM" > /sys/block/zram0/comp_algorithm; then
    echo "[x] 压缩算法写入失败。"
    exit 21
fi
ZRAM_BYTES=$(awk "BEGIN {printf \"%.0f\", $ZRAM_SIZE_GB * 1024 * 1024 * 1024}")
if ! echo "$ZRAM_BYTES" > /sys/block/zram0/disksize; then
    echo "[x] disksize 写入失败。"
    exit 22
fi

# 挂载
echo "[*] 挂载新 ZRAM..."
if ! mkswap /dev/block/zram0; then
    echo "[x] mkswap 执行失败。"
    exit 23
fi
if ! swapon /dev/block/zram0; then
    echo "[x] swapon 执行失败。"
    exit 24
fi

# 参数微调
echo "[*] 注入内核调优参数..."
if ! echo "$SWAPPINESS" > /proc/sys/vm/swappiness; then
    echo "[x] swappiness 写入失败。"
    exit 25
fi
if ! echo "$WATERMARK_SCALE" > /proc/sys/vm/watermark_scale_factor; then
    echo "[x] watermark_scale_factor 写入失败。"
    exit 26
fi

echo "[√] 所有底层操作已完成。"
exit 0