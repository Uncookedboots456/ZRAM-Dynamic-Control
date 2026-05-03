#!/system/bin/sh
SKIPUNZIP=0
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_current_algorithm() {
    local raw current
    raw=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)
    current=$(echo "$raw" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
    if [ -z "$current" ]; then
        current=$(echo "$raw" | awk '{print $1}')
    fi
    echo "${current:-lz4}"
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

read_zram_size_mb() {
    local bytes mb
    bytes=$(cat /sys/block/zram0/disksize 2>/dev/null)
    case "$bytes" in
        ''|*[!0-9]*) echo "0"; return ;;
    esac
    mb=$(awk -v bytes="$bytes" 'BEGIN {printf "%d", bytes / 1024 / 1024}')
    case "$mb" in
        ''|*[!0-9]*) mb=0 ;;
    esac
    echo "$mb"
}

format_gb_from_mb() {
    awk -v mb="$1" 'BEGIN {printf "%.2f", mb / 1024}'
}

MEM_TOTAL_MB=$(read_mem_total_mb)
CURRENT_ZRAM_MB=$(read_zram_size_mb)
CURRENT_ALGO=$(read_current_algorithm)
CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null)
CURRENT_SWAPPINESS=${CURRENT_SWAPPINESS:-80}
CURRENT_WATERMARK=$(cat /proc/sys/vm/watermark_scale_factor 2>/dev/null)
CURRENT_WATERMARK=${CURRENT_WATERMARK:-50}
MEM_TOTAL_GB=$(format_gb_from_mb "$MEM_TOTAL_MB")
CURRENT_ZRAM_GB=$(format_gb_from_mb "$CURRENT_ZRAM_MB")

cat > "$CONF" <<EOF
ENABLED=0
ZRAM_SIZE_MB=${CURRENT_ZRAM_MB}
COMP_ALGORITHM=${CURRENT_ALGO}
SWAPPINESS=${CURRENT_SWAPPINESS}
WATERMARK_SCALE_FACTOR=${CURRENT_WATERMARK}
EOF

ui_print "- 正在安装 UncookedBoot ZRAM 模块..."
ui_print "- 核心架构: Hybrid (Action + WebUI)"
ui_print "- 检测到物理内存: ${MEM_TOTAL_MB}MB (~${MEM_TOTAL_GB}GB)"
ui_print "- 检测到当前 ZRAM: ${CURRENT_ZRAM_MB}MB (~${CURRENT_ZRAM_GB}GB)"
ui_print "- 检测到压缩算法: ${CURRENT_ALGO}"
ui_print "- 检测到 Swappiness: ${CURRENT_SWAPPINESS}"
ui_print "- 检测到 Watermark Scale: ${CURRENT_WATERMARK}"
ui_print "- 默认状态: 未启用，不会在开机时主动修改 ZRAM"
ui_print "- 如需启用，请进入 WebUI 保存并立即执行，或保存后等待下次开机自动应用"

set_perm_recursive "$MODDIR" 0 0 0755 0644
set_perm "$MODDIR/service.sh" 0 0 0755
set_perm "$MODDIR/zram_ctrl.sh" 0 0 0755
set_perm "$MODDIR/action.sh" 0 0 0755