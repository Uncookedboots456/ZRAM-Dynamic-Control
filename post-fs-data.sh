#!/system/bin/sh
MODDIR=${0%/*}

sh "$MODDIR/zram_ctrl.sh" --sync >/dev/null 2>&1
