#!/system/bin/sh
MODDIR=${0%/*}
CONF="$MODDIR/config.conf"

read_conf() {
    local key value
    key="$1"
    value=$(grep "^${key}=" "$CONF" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r')
    echo "$value"
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

sleep 60

if [ "$(read_conf ENABLED)" != "1" ]; then
    exit 0
fi

sh "$MODDIR/zram_ctrl.sh"