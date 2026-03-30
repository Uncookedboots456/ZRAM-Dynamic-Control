#!/system/bin/sh
# KernelSU / Magisk 操作按钮触发器

echo "====================================="
echo "   UncookedBoot ZRAM 控制台 v1.0     "
echo "====================================="
echo "[*] 开始执行热重载逻辑..."
echo "-------------------------------------"

# 使用绝对路径呼叫同目录下的核心脚本
sh /data/adb/modules/zram_12g_uncookedboot/zram_ctrl.sh

echo "-------------------------------------"
echo "[*] 系统当前 ZRAM/Swap 真实状态看板："

SWAP_TOTAL=$(grep -i '^SwapTotal:' /proc/meminfo | awk '{print $2 " " $3}')
SWAP_FREE=$(grep -i '^SwapFree:' /proc/meminfo | awk '{print $2 " " $3}')

echo "  > 操作系统挂载总计: $SWAP_TOTAL"
echo "  > 当前剩余空闲空间: $SWAP_FREE"

echo "====================================="
echo "[*] 窗口将在 8 秒后自动关闭..."
sleep 8