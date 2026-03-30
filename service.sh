#!/system/bin/sh
# 开机启动脚本

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# 延迟 60 秒，等待 Uperf 等其他模块释放控制权
sleep 60

# 后台静默调用绝对路径脚本
sh /data/adb/modules/zram_12g_uncookedboot/zram_ctrl.sh

# 发送通知 (降权执行，提升在 ColorOS 等定制系统上的存活率)
su 2000 -c "cmd notification post -S bigtext -t 'ZRAM 控制器' 'ZRAM_Task' '开机自动调度已执行完毕，详见 KSU Action 看板'"
busybox httpd -p 8080 -h /data/adb/modules/zram_12g_uncookedboot/www