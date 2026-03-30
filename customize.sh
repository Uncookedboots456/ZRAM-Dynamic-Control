#!/system/bin/sh
# 安装界面的 UI 输出与权限配置

ui_print "***************************************"
ui_print "* ZRAM 动态控制核心 v1.0 (纯脚本版)   *"
ui_print "* 创作者: UncookedBoot (一只大海兲)         *"
ui_print "***************************************"
ui_print "- 正在部署扁平化架构脚本..."

# 直接对根目录下的脚本进行赋权
set_perm $MODPATH/zram_ctrl.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/service.sh 0 0 0755

set_perm_recursive $MODPATH/www/cgi-bin 0 0 0755 0755
ui_print "---------------------------------------"
ui_print "- 部署完成！完全解耦 Magic Mount。"
ui_print "- 重启后生效，支持通过管理器操作按钮随时控制。"