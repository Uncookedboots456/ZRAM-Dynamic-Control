# ZRAM-Dynamic-Control
⚡ A script-only, hot-reloadable ZRAM dynamic controller for modern Android devices (KernelSU/Magisk).

# ZRAM Dynamic Control (ZRAM 动态控制核心)

🌍 *[English Version Below](#english-version)*

这是一个专为现代 Android 环境设计的轻量级 ZRAM 动态调度核心。采用彻底解耦的纯脚本架构，支持在 Root 管理器中一键无感热重载，精准控制底层内存交换策略。

**创作者:** UncookedBoot (大海兲)  
**协议:** GPLv3  
**兼容性:** KernelSU / Magisk / APatch 

---

## 🇨🇳 中文说明

### 💡 核心原理 (How it Works)

本模块摒弃了传统的粗暴修改，采用现代化的模块开发标准：
* **去系统挂载化 (Script-Only 架构):** 彻底抛弃传统的 Magic Mount (`/system` 目录投射) 机制。所有脚本均在 `/data/adb/modules/` 物理绝对路径下直接运行，100% 免疫深度定制系统的 SELinux 拦截与命名空间隔离。
* **极客级热重载 (Action Trigger):** 深度适配 Root 管理器的原生 Action 按钮。修改配置文件后，终端脚本会直接覆写 Linux 内核的 `/sys/block/zram0/disksize` 节点，**无需重启设备**。
* **智能防爆机制 (Safe-Swap):** 在执行底层 `swapoff` 卸载动作前，脚本会自动拉起 `sync` 和 `drop_caches` 释放物理内存缓存，完美规避因物理内存爆满导致的卸载失败与系统死锁。
* **闭环状态校验:** 每次热重载都会对比底层硬件节点与 `/proc/meminfo` 实际挂载状态，并在控制台实时回显。

### 🚀 使用指南

**1. 初始部署**
在 Releases 页面下载 `.zip` 刷机包，通过 KernelSU/Magisk/APatch 刷入并重启设备。开机脚本内置 60 秒延时，以确保能稳定覆盖其他性能模块的默认设定。

**2. 声明式配置**
使用文本编辑器（如 MT 管理器）打开以下路径的配置文件：
`/data/adb/modules/zram_12g_uncookedboot/config.conf`
将 `ZRAM_SIZE_GB=` 后的数值修改为你期望的容量（仅填纯数字，如 8、12、16）。

**3. 一键热生效**
保存配置后，进入 Root 管理器的模块列表，点击本模块描述下方的 **操作 (Action)** 按钮。等待终端运行完毕，新容量即刻生效。

### ⚠️ 用户须知
* **默认配置:** 本模块默认设定为 **12GB**，这对于搭载大内存（如骁龙 8 Gen 3）的设备是一个兼顾前台流畅度与后台驻留的“甜点”容量。
* **冲突说明:** 若设备中存在高频轮询并强制锁定 ZRAM 大小的其他守护进程，本模块的热重载可能会被其后续动作覆盖。
* **免责声明:** 修改 Linux 内核底层节点具有一定风险。作者不对因极端内存调度导致的设备卡顿、数据丢失或重启负责。

---

## 🇬🇧 English Version

### 💡 Principles (How it Works)

This module Abandons brute-force modifications in favor of modern module development standards:
* **Script-Only Architecture:** Completely discards the traditional Magic Mount (`/system` projection) mechanism. All scripts run directly under the physical absolute path of `/data/adb/modules/`, ensuring 100% immunity to SELinux interception and mount namespace isolation on heavily customized ROMs.
* **Seamless Hot-Reload (Action Trigger):** Fully adapted to the native Action button in Root Managers. After modifying the config file, the script directly overwrites the `/sys/block/zram0/disksize` kernel node without requiring a device reboot.
* **Safe-Swap Mechanism:** Before executing the underlying `swapoff` command, the script automatically triggers `sync` and `drop_caches` to free up physical memory, perfectly avoiding unmount failures and system deadlocks caused by full RAM.
* **Closed-Loop Verification:** Every hot-reload compares the underlying hardware node with the actual mount status in `/proc/meminfo` and echoes it in real-time in the console.

### 🚀 Usage Guide

**1. Initial Deployment**
Download the `.zip` package from the Releases page, flash it via KernelSU/Magisk/APatch, and reboot. The boot script has a built-in 60-second delay to stably override default settings from other performance modules.

**2. Declarative Configuration**
Open the config file using a text editor at the following path:
`/data/adb/modules/zram_12g_uncookedboot/config.conf`
Change the value after `ZRAM_SIZE_GB=` to your desired capacity (numbers only, e.g., 8, 12, 16).

**3. One-Click Application**
After saving the configuration, go to your Root Manager's module list and click the **Action** button below this module's description. The new capacity will take effect immediately after the terminal finishes running.

### ⚠️ User Notice
* **Default Setting:** The module defaults to **12GB**, which is a "sweet spot" capacity balancing foreground fluidity and background app retention for devices with large RAM (e.g., Snapdragon 8 Gen 3).
* **Conflict Warning:** If there are other daemons on your device that poll at high frequencies and force-lock the ZRAM size, the hot-reload from this module might be overwritten by their subsequent actions.
* **Disclaimer:** Modifying underlying Linux kernel nodes involves inherent risks. The author is not responsible for device lag, data loss, or random reboots caused by extreme memory scheduling.git push -u origin main
