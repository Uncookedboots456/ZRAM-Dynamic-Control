#!/system/bin/sh
MODDIR=${0%/*}
PLAIN_MODE=0

if [ "$1" = "--plain" ]; then
    PLAIN_MODE=1
fi

if [ "$PLAIN_MODE" != "1" ]; then
    echo "==============================="
    echo "  UncookedBoot ZRAM 手动重载   "
    echo "==============================="
    echo ""
fi

sh "$MODDIR/zram_ctrl.sh"
STATUS=$?

if [ "$PLAIN_MODE" != "1" ]; then
    echo ""
    echo "==============================="
    echo "  操作结束。按音量键退出...    "
    echo "==============================="
fi

exit "$STATUS"