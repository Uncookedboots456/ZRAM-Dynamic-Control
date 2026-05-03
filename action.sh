#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_conf() {
    local key value
    key="$1"
    value=$(grep "^${key}=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r')
    echo "$value"
}

echo "==============================="
echo "  UncookedBoot ZRAM 手动重载   "
echo "==============================="
echo ""

if [ "$(read_conf ENABLED)" != "1" ]; then
    echo "[!] 当前未启用自动接管。"
    echo "[!] 请先进入 WebUI 保存配置，再返回点击 Action。"
else
    sh "$MODDIR/zram_ctrl.sh"
fi

echo ""
echo "==============================="
echo "  操作结束。按音量键退出...    "
echo "==============================="