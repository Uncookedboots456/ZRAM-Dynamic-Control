#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"
if [ "$1" = '--locked' ]; then
    MODE=${2:-apply}
    LOCK_HELD=1
else
    MODE=${1:-apply}
    LOCK_HELD=0
fi
LOCK_FILE="$MODDIR/.zram_ctrl.lock"
SCENE_MODDIR=/data/adb/modules/scene_swap_controller
SCENE_CONF=/data/swap_config.conf

read_conf() {
    grep "^$1=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r\n '
}

read_scene_conf() {
    grep "^$1=" "$SCENE_CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r\n '
}

read_mem_total_mb() {
    local reported_gb
    reported_gb=$(getprop ro.oplus.memory.size 2>/dev/null)
    case "$reported_gb" in
        ''|*[!0-9]*) ;;
        *) [ "$reported_gb" -gt 0 ] 2>/dev/null && { echo $((reported_gb * 1024)); return; } ;;
    esac
    awk '/MemTotal/ {printf "%d", $2 / 1024}' /proc/meminfo 2>/dev/null
}

read_mem_available_mb() {
    awk '/MemAvailable/ {printf "%d", $2 / 1024}' /proc/meminfo 2>/dev/null
}

read_swap_used_mb() {
    awk '/SwapTotal/ {total=$2} /SwapFree/ {free=$2} END {printf "%d", (total - free) / 1024}' /proc/meminfo 2>/dev/null
}

read_current_algorithm() {
    local raw current
    raw=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)
    current=$(echo "$raw" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
    [ -n "$current" ] || current=$(echo "$raw" | awk '{print $1}')
    echo "$current"
}

read_zram_size_mb() {
    local bytes
    bytes=$(cat /sys/block/zram0/disksize 2>/dev/null)
    case "$bytes" in ''|*[!0-9]*) echo 0 ;; *) awk -v bytes="$bytes" 'BEGIN {printf "%d", bytes / 1048576}' ;; esac
}

format_gb_from_mb() {
    awk -v mb="$1" 'BEGIN {printf "%.2f", mb / 1024}'
}

is_positive_integer() {
    case "$1" in ''|*[!0-9]*) return 1 ;; *) [ "$1" -gt 0 ] 2>/dev/null ;; esac
}

is_non_negative_integer() {
    case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

swap_is_active() {
    awk '$1 ~ /(^|\/)zram0$/ {found=1} END {exit !found}' /proc/swaps 2>/dev/null
}

is_supported_algorithm() {
    [ -r /sys/block/zram0/comp_algorithm ] || return 1
    tr -d '[]' < /sys/block/zram0/comp_algorithm | tr ' ' '\n' | grep -Fxq "$1"
}

escape_for_single_quotes() {
    printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

notify_result() {
    local title text safe_title safe_text
    title="$1"
    text="$2"
    command -v log >/dev/null 2>&1 && log -t zram_dynamic_control "$title: $text"
    if command -v cmd >/dev/null 2>&1; then
        safe_title=$(escape_for_single_quotes "$title")
        safe_text=$(escape_for_single_quotes "$text")
        su 2000 -c "cmd notification post -t '$safe_title' zram_dynamic_control '$safe_text'" >/dev/null 2>&1 || \
            log -t zram_dynamic_control 'System notification unavailable'
    fi
}

fail() {
    local code message
    code="$1"
    message="$2"
    echo "$message"
    [ "$MODE" = '--check' ] || notify_result 'ZRAM apply failed' "$message"
    exit "$code"
}

read_target_zram_mb() {
    local mb kb gb
    mb=$(read_conf ZRAM_SIZE_MB)
    if is_positive_integer "$mb"; then echo "$mb"; return; fi
    kb=$(read_conf ZRAM_SIZE_KB)
    if is_positive_integer "$kb"; then awk -v kb="$kb" 'BEGIN {printf "%d", kb / 1024}'; return; fi
    gb=$(read_conf ZRAM_SIZE_GB)
    if is_positive_integer "$gb"; then awk -v gb="$gb" 'BEGIN {printf "%d", gb * 1024}'; return; fi
    echo 0
}

scene_owns_zram() {
    [ -d "$SCENE_MODDIR" ] && [ ! -e "$SCENE_MODDIR/disable" ] && [ ! -e "$SCENE_MODDIR/remove" ] && \
        [ -f "$SCENE_CONF" ] && [ "$(read_scene_conf zram)" = true ]
}

scene_config_matches() {
    [ "$(read_scene_conf zram)" = true ] && \
        [ "$(read_scene_conf zram_size)" = "$ZRAM_SIZE_MB" ] && \
        [ "$(read_scene_conf comp_algorithm)" = "$COMP_ALGORITHM" ] && \
        [ "$(read_scene_conf swappiness)" = "$SWAPPINESS" ] && \
        [ "$(read_scene_conf watermark_scale_factor)" = "$WATERMARK_SCALE" ]
}

scene_runtime_matches() {
    local runtime_zram_mb
    runtime_zram_mb=$(read_zram_size_mb)
    { [ "$runtime_zram_mb" = "$ZRAM_SIZE_MB" ] || \
        { [ "$(read_scene_conf zram_writeback)" = true ] && \
            [ "$runtime_zram_mb" = "$((ZRAM_SIZE_MB + 4096))" ]; }; } && \
        [ "$(read_current_algorithm)" = "$COMP_ALGORITHM" ] && \
        [ "$(cat /proc/sys/vm/swappiness 2>/dev/null)" = "$SWAPPINESS" ] && \
        [ "$(cat /proc/sys/vm/watermark_scale_factor 2>/dev/null)" = "$WATERMARK_SCALE" ] && \
        swap_is_active
}

sync_scene_config() {
    local tmp scene_file_mode
    for key in zram_size comp_algorithm swappiness watermark_scale_factor; do
        grep -q "^$key=" "$SCENE_CONF" 2>/dev/null || fail 27 "[x] Scene 配置缺少字段: $key"
    done
    tmp=$(mktemp "${SCENE_CONF}.XXXXXX") || fail 28 "[x] 无法创建 Scene 配置临时文件。"
    if ! sed \
        -e "s/^zram_size=.*/zram_size=$ZRAM_SIZE_MB/" \
        -e "s/^comp_algorithm=.*/comp_algorithm=$COMP_ALGORITHM/" \
        -e "s/^swappiness=.*/swappiness=$SWAPPINESS/" \
        -e "s/^watermark_scale_factor=.*/watermark_scale_factor=$WATERMARK_SCALE/" \
        "$SCENE_CONF" > "$tmp"; then
        rm -f "$tmp"
        fail 29 '[x] Scene 配置写入失败。'
    fi
    scene_file_mode=$(stat -c %a "$SCENE_CONF" 2>/dev/null)
    [ -n "$scene_file_mode" ] && chmod "$scene_file_mode" "$tmp"
    if ! mv -f "$tmp" "$SCENE_CONF"; then
        rm -f "$tmp"
        fail 30 '[x] Scene 配置替换失败。'
    fi
    echo '[√] 已同步到 Scene 配置；Scene 会在下次开机应用。'
}

validate_config() {
    if ! is_positive_integer "$ZRAM_SIZE_MB"; then fail 12 '[x] ZRAM_SIZE_MB 必须是正整数。'; fi
    if [ "$ZRAM_SIZE_MB" -gt "$MEM_TOTAL_MB" ] 2>/dev/null; then fail 13 "[x] 目标 ZRAM ${ZRAM_SIZE_MB}MB 超过物理内存上限 ${MEM_TOTAL_MB}MB。"; fi
    if ! is_supported_algorithm "$COMP_ALGORITHM"; then fail 14 "[x] 当前内核不支持压缩算法: $COMP_ALGORITHM"; fi
    if ! is_non_negative_integer "$SWAPPINESS" || [ "$SWAPPINESS" -gt 200 ] 2>/dev/null; then fail 15 '[x] SWAPPINESS 必须是 0 到 200 之间的整数。'; fi
    if ! is_positive_integer "$WATERMARK_SCALE"; then fail 16 '[x] WATERMARK_SCALE_FACTOR 必须是正整数。'; fi
    if ! is_positive_integer "$MIN_SWAPOFF_HEADROOM_MB"; then fail 17 '[x] MIN_SWAPOFF_HEADROOM_MB 必须是正整数。'; fi
}

check_direct_environment() {
    for command in swapoff swapon mkswap; do
        command -v "$command" >/dev/null 2>&1 || fail 18 "[x] 缺少命令: $command"
    done
    [ -w /sys/block/zram0/disksize ] && [ -w /sys/block/zram0/comp_algorithm ] && [ -w /sys/block/zram0/reset ] || \
        fail 19 '[x] ZRAM sysfs 节点不可写。'
}

check_swapoff_headroom() {
    local available used headroom
    available=$(read_mem_available_mb)
    used=$(read_swap_used_mb)
    is_non_negative_integer "$available" && is_non_negative_integer "$used" || fail 20 '[x] 无法读取内存余量。'
    headroom=$((available - used))
    if [ "$headroom" -lt "$MIN_SWAPOFF_HEADROOM_MB" ]; then
        fail 21 "[x] swapoff 安全余量不足: ${headroom}MB < ${MIN_SWAPOFF_HEADROOM_MB}MB。"
    fi
}

write_vm_parameters() {
    if ! echo "$SWAPPINESS" > /proc/sys/vm/swappiness; then fail 25 '[x] swappiness 写入失败。'; fi
    if ! echo "$WATERMARK_SCALE" > /proc/sys/vm/watermark_scale_factor; then fail 26 '[x] watermark_scale_factor 写入失败。'; fi
}

[ -f "$CONF" ] || fail 11 "[x] 配置文件不存在: $CONF"

ENABLED=$(read_conf ENABLED)
ZRAM_SIZE_MB=$(read_target_zram_mb)
COMP_ALGORITHM=$(read_conf COMP_ALGORITHM)
SWAPPINESS=$(read_conf SWAPPINESS)
WATERMARK_SCALE=$(read_conf WATERMARK_SCALE_FACTOR)
MIN_SWAPOFF_HEADROOM_MB=$(read_conf MIN_SWAPOFF_HEADROOM_MB)
MEM_TOTAL_MB=$(read_mem_total_mb)

ENABLED=${ENABLED:-0}
ZRAM_SIZE_MB=${ZRAM_SIZE_MB:-0}
COMP_ALGORITHM=${COMP_ALGORITHM:-lz4}
SWAPPINESS=${SWAPPINESS:-80}
WATERMARK_SCALE=${WATERMARK_SCALE:-50}
MIN_SWAPOFF_HEADROOM_MB=${MIN_SWAPOFF_HEADROOM_MB:-1024}
MEM_TOTAL_MB=${MEM_TOTAL_MB:-1}

if [ "$ENABLED" != 1 ] && [ "$MODE" != '--check' ]; then
    echo '[!] 当前配置未启用，请先在 WebUI 保存配置并执行 action。'
    exit 10
fi

if [ "$LOCK_HELD" != 1 ]; then
    for busybox in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox; do
        [ -x "$busybox" ] || continue
        "$busybox" flock -n "$LOCK_FILE" /system/bin/sh "$0" --locked "$MODE"
        lock_status=$?
        [ "$lock_status" -eq 1 ] && fail 9 '[x] ZRAM 操作正在执行中。'
        exit "$lock_status"
    done
    fail 9 '[x] 缺少 BusyBox flock，无法保证单实例执行。'
fi

validate_config

if scene_owns_zram; then
    case "$MODE" in
        --check)
            echo '[√] Scene owns ZRAM; direct sysfs writes are disabled.'
            echo "[*] Scene target: ${ZRAM_SIZE_MB}MB | ${COMP_ALGORITHM} | Swap:${SWAPPINESS} | WM:${WATERMARK_SCALE}"
            exit 0
            ;;
        --sync)
            sync_scene_config
            exit 0
            ;;
        --boot)
            if scene_config_matches; then
                write_vm_parameters
            fi
            if scene_config_matches && scene_runtime_matches; then
                echo '[√] Scene 已应用 ZRAM 配置。'
                notify_result 'ZRAM applied by Scene' "${ZRAM_SIZE_MB}MB | ${COMP_ALGORITHM}"
                exit 0
            fi
            fail 31 '[x] Scene 未在本次开机应用预期的 ZRAM 配置。'
            ;;
        *)
            sync_scene_config
            echo 'SCENE_DEFERRED=1'
            notify_result 'ZRAM config saved' 'Scene will apply it on next boot.'
            exit 0
            ;;
    esac
fi

if [ "$MODE" = '--sync' ]; then
    echo 'SYNC_SKIPPED=1'
    exit 0
fi

check_direct_environment
if [ "$MODE" = '--check' ]; then
    check_swapoff_headroom
    echo '[√] Direct ZRAM preflight passed.'
    exit 0
fi

CURRENT_ZRAM_MB=$(read_zram_size_mb)
CURRENT_ALGORITHM=$(read_current_algorithm)
if swap_is_active && [ "$CURRENT_ZRAM_MB" = "$ZRAM_SIZE_MB" ] && [ "$CURRENT_ALGORITHM" = "$COMP_ALGORITHM" ]; then
    write_vm_parameters
    echo '[√] ZRAM 配置已匹配，仅更新 VM 参数。'
    notify_result 'ZRAM parameters applied' "${ZRAM_SIZE_MB}MB | ${COMP_ALGORITHM}"
    exit 0
fi

check_swapoff_headroom
MEM_TOTAL_GB=$(format_gb_from_mb "$MEM_TOTAL_MB")
TARGET_ZRAM_GB=$(format_gb_from_mb "$ZRAM_SIZE_MB")

echo '[*] 开始执行 ZRAM 核心引擎...'
echo "[*] 物理内存上限: ${MEM_TOTAL_MB}MB (~${MEM_TOTAL_GB}GB)"
echo "[*] 目标配置: ${ZRAM_SIZE_MB}MB (~${TARGET_ZRAM_GB}GB) | ${COMP_ALGORITHM} | Swap:${SWAPPINESS} | WM:${WATERMARK_SCALE}"

sync
if swap_is_active && ! swapoff /dev/block/zram0; then fail 22 '[x] swapoff 执行失败。'; fi
if ! echo 1 > /sys/block/zram0/reset; then fail 23 '[x] zram reset 失败。'; fi
if ! echo "$COMP_ALGORITHM" > /sys/block/zram0/comp_algorithm; then fail 24 '[x] 压缩算法写入失败。'; fi
ZRAM_BYTES=$(awk -v mb="$ZRAM_SIZE_MB" 'BEGIN {printf "%.0f", mb * 1048576}')
if ! echo "$ZRAM_BYTES" > /sys/block/zram0/disksize; then fail 25 '[x] disksize 写入失败。'; fi
if ! mkswap /dev/block/zram0; then fail 26 '[x] mkswap 执行失败。'; fi
if ! swapon /dev/block/zram0; then fail 27 '[x] swapon 执行失败。'; fi
write_vm_parameters

echo '[√] 所有底层操作已完成。'
notify_result 'ZRAM applied' "${ZRAM_SIZE_MB}MB | ${COMP_ALGORITHM}"
