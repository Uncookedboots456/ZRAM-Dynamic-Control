#!/system/bin/sh
MODDIR=${0%/*}

echo "==============================="
echo "  UncookedBoot ZRAM 手动重载   "
echo "==============================="
echo ""

# 调用核心引擎并实时输出
sh "$MODDIR/zram_ctrl.sh"

echo ""
echo "==============================="
echo "  操作结束。按音量键退出...    "
echo "==============================="