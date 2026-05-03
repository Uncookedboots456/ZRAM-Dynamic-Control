#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_conf() {
    local key value
    key="$1"
    value=$(grep "^${key}=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r')
    echo "$value"
}

notify_result() {
    local title text
    title="$1"
    text="$2"
    if command -v cmd >/dev/null 2>&1; then
        cmd notification post -t "$title" zram_dynamic_control "$text" >/dev/null 2>&1
    fi
}

# 等待系统开机完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# 延迟 60 秒避开开机高峰期，然后执行核心引擎
sleep 60

if [ "$(read_conf ENABLED)" != "1" ]; then
    exit 0
fi

if sh "$MODDIR/zram_ctrl.sh"; then
    ZRAM_SIZE_GB=$(read_conf ZRAM_SIZE_GB)
    COMP_ALGORITHM=$(read_conf COMP_ALGORITHM)
    notify_result "ZRAM 已自动应用" "${ZRAM_SIZE_GB}GB / ${COMP_ALGORITHM} 已在开机后自动生效"
else
    notify_result "ZRAM 自动应用失败" "开机后自动应用失败，请进入模块 Action 查看终端日志"
fi