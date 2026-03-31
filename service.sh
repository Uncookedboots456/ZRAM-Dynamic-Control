#!/system/bin/sh
MODDIR=${0%/*}

# 等待系统开机完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# 延迟 60 秒避开开机高峰期，然后执行核心引擎
sleep 60
sh "$MODDIR/zram_ctrl.sh" &