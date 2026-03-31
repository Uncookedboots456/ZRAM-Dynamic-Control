#!/system/bin/sh
MODDIR="/data/adb/modules/zram_12g_uncookedboot"
CONF="$MODDIR/config.conf"

# 1. 纯粹地读取四个配置，提供安全回退值
ZRAM_SIZE_GB=$(grep "^ZRAM_SIZE_GB=" "$CONF" | cut -d'=' -f2 | tr -d '\r\n ')
ZRAM_SIZE_GB=${ZRAM_SIZE_GB:-12}

COMP_ALGORITHM=$(grep "^COMP_ALGORITHM=" "$CONF" | cut -d'=' -f2 | tr -d '\r\n ')
COMP_ALGORITHM=${COMP_ALGORITHM:-lz4}

SWAPPINESS=$(grep "^SWAPPINESS=" "$CONF" | cut -d'=' -f2 | tr -d '\r\n ')
SWAPPINESS=${SWAPPINESS:-80}

WATERMARK_SCALE=$(grep "^WATERMARK_SCALE_FACTOR=" "$CONF" | cut -d'=' -f2 | tr -d '\r\n ')
WATERMARK_SCALE=${WATERMARK_SCALE:-50}

echo "[*] 开始执行 ZRAM 核心引擎..."
echo "[*] 目标配置: ${ZRAM_SIZE_GB}GB | ${COMP_ALGORITHM} | Swap:${SWAPPINESS} | WM:${WATERMARK_SCALE}"

# 2. 释放缓存
sync
echo 3 > /proc/sys/vm/drop_caches

# 3. 卸载现有 ZRAM
echo "[*] 正在卸载旧节点..."
swapoff /dev/block/zram0
echo 1 > /sys/block/zram0/reset

# 4. 下发底层协议与容量 (awk 防止溢出变0)
echo "[*] 正在重新分配空间与协议..."
echo "$COMP_ALGORITHM" > /sys/block/zram0/comp_algorithm
ZRAM_BYTES=$(awk "BEGIN {printf \"%.0f\", $ZRAM_SIZE_GB * 1024 * 1024 * 1024}")
echo "$ZRAM_BYTES" > /sys/block/zram0/disksize

# 5. 挂载
echo "[*] 挂载新 ZRAM..."
mkswap /dev/block/zram0
swapon /dev/block/zram0

# 6. 参数微调
echo "[*] 注入内核调优参数..."
echo "$SWAPPINESS" > /proc/sys/vm/swappiness
echo "$WATERMARK_SCALE" > /proc/sys/vm/watermark_scale_factor

echo "[√] 所有底层操作已完成。"