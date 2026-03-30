#!/system/bin/sh
# UncookedBoot ZRAM 核心控制逻辑

# 绝对物理路径，无视挂载命名空间
MODULE_DIR="/data/adb/modules/zram_12g_uncookedboot"
CONFIG_FILE="$MODULE_DIR/config.conf"

echo "[*] 正在读取配置文件..."
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[!] 致命错误：找不到配置文件 config.conf"
    exit 1
fi

TARGET_GB=$(grep "^ZRAM_SIZE_GB=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')

if [ -z "$TARGET_GB" ] || ! echo "$TARGET_GB" | grep -qE '^[0-9]+$'; then
    echo "[!] 致命错误：读取到的 ZRAM 大小无效 ($TARGET_GB)"
    exit 1
fi

TARGET_BYTES=$((TARGET_GB * 1024 * 1024 * 1024))
echo "[*] 目标 ZRAM 大小: ${TARGET_GB}GB"

# 核心防爆机制：先清理缓存，防止 swapoff 因内存不足而失败
echo "[*] 正在释放物理内存缓存，确保数据有空间回吐..."
sync
echo 3 > /proc/sys/vm/drop_caches
sleep 2

echo "[*] 正在停止 ZRAM (若占用较高可能需要数秒)..."
swapoff /dev/block/zram0

if [ $? -ne 0 ]; then
    echo "[!] 致命错误：swapoff 执行失败！物理内存已满或被强占用。"
    echo "[!] 建议：清理后台应用后再尝试触发。"
    exit 1
fi

echo "[*] 重置并应用新容量..."
echo 1 > /sys/block/zram0/reset
echo $TARGET_BYTES > /sys/block/zram0/disksize

echo "[*] 正在格式化并挂载..."
mkswap /dev/block/zram0
swapon /dev/block/zram0

# 闭环验证
ACTUAL_BYTES=$(cat /sys/block/zram0/disksize)
ACTUAL_GB=$((ACTUAL_BYTES / 1024 / 1024 / 1024))

echo "---------------------------------------"
if [ "$ACTUAL_BYTES" = "$TARGET_BYTES" ]; then
    echo "[√] 底层节点重写成功！当前硬件限制: ~${ACTUAL_GB} GB"
    # 写日志
    TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo "✅ UncookedBoot ZRAM Task: [ $TIME ] 成功重载为 ${TARGET_GB}GB" > /sdcard/ZRAM_Task.log
else
    echo "[X] 修改失败：内核拒绝了新的容量设定！"
fi