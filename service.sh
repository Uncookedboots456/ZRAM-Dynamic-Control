#!/system/bin/sh
# Boot-time ZRAM control script

MODULE_DIR="/data/adb/modules/zram_12g_uncookedboot"
CONFIG_FILE="$MODULE_DIR/config.conf"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Read BOOT_DELAY_SEC from config.conf
BOOT_DELAY_SEC=$(grep "^BOOT_DELAY_SEC=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')

# Validate BOOT_DELAY_SEC
if [ -z "$BOOT_DELAY_SEC" ] || ! echo "$BOOT_DELAY_SEC" | grep -qE '^[0-9]+$'; then
    BOOT_DELAY_SEC=60 # Default to 60 seconds if invalid
fi

echo "ZRAM module: Waiting for $BOOT_DELAY_SEC seconds before initial setup..."
sleep "$BOOT_DELAY_SEC"

# Execute the core control script in the background
sh "$MODULE_DIR/zram_ctrl.sh" &