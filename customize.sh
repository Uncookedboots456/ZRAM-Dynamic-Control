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

read_zram_size_kb() {
    local bytes kb
    bytes=$(cat /sys/block/zram0/disksize 2>/dev/null)
    case "$bytes" in
        ''|*[!0-9]*) echo "0"; return ;;
    esac
    kb=$(awk -v bytes="$bytes" 'BEGIN {printf "%d", bytes / 1024}')
    case "$kb" in
        ''|*[!0-9]*) kb=0 ;;
    esac
    echo "$kb"
}

format_gb_from_kb() {
    awk -v kb="$1" 'BEGIN {printf "%.2f", kb / 1024 / 1024}'
}

MEM_TOTAL_KB=$(read_mem_total_kb)
CURRENT_ZRAM_KB=$(read_zram_size_kb)
CURRENT_ALGO=$(read_current_algorithm)
CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null)
CURRENT_SWAPPINESS=${CURRENT_SWAPPINESS:-80}
CURRENT_WATERMARK=$(cat /proc/sys/vm/watermark_scale_factor 2>/dev/null)
CURRENT_WATERMARK=${CURRENT_WATERMARK:-50}
MEM_TOTAL_GB=$(format_gb_from_kb "$MEM_TOTAL_KB")
CURRENT_ZRAM_GB=$(format_gb_from_kb "$CURRENT_ZRAM_KB")

cat > "$CONF" <<EOF
ENABLED=0
ZRAM_SIZE_KB=${CURRENT_ZRAM_KB}
COMP_ALGORITHM=${CURRENT_ALGO}
SWAPPINESS=${CURRENT_SWAPPINESS}
WATERMARK_SCALE_FACTOR=${CURRENT_WATERMARK}
EOF

ui_print "- 正在安装 UncookedBoot ZRAM 模块..."
ui_print "- 核心架构: Hybrid (Action + WebUI)"
ui_print "- 检测到物理内存: ${MEM_TOTAL_KB}KB (~${MEM_TOTAL_GB}GB)"
ui_print "- 检测到当前 ZRAM: ${CURRENT_ZRAM_KB}KB (~${CURRENT_ZRAM_GB}GB)"
ui_print "- 检测到压缩算法: ${CURRENT_ALGO}"
ui_print "- 检测到 Swappiness: ${CURRENT_SWAPPINESS}"
ui_print "- 检测到 Watermark Scale: ${CURRENT_WATERMARK}"
ui_print "- 默认状态: 未启用，不会在开机时主动修改 ZRAM"
ui_print "- 如需启用，请进入 WebUI 保存并立即执行，或保存后等待下次开机自动应用"

set_perm_recursive "$MODDIR" 0 0 0755 0644
set_perm "$MODDIR/service.sh" 0 0 0755
set_perm "$MODDIR/zram_ctrl.sh" 0 0 0755
set_perm "$MODDIR/action.sh" 0 0 0755