#!/system/bin/sh
SKIPUNZIP=0
MODDIR=${0%/*}

ui_print "- 正在安装 UncookedBoot ZRAM 模块..."
ui_print "- 核心架构: Hybrid (Action + WebUI)"

set_perm_recursive "$MODDIR" 0 0 0755 0644
set_perm "$MODDIR/service.sh" 0 0 0755
set_perm "$MODDIR/zram_ctrl.sh" 0 0 0755
set_perm "$MODDIR/action.sh" 0 0 0755