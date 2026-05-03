# ZRAM-Dynamic-Control
⚡ A script-only, hot-reloadable ZRAM dynamic controller for modern Android devices (KernelSU/Magisk).

# ZRAM Dynamic Control (ZRAM 动态控制核心)

🌍 *[English Version Below](#english-version)*

这是一个专为现代 Android 环境设计的轻量级 ZRAM 动态调度核心。采用彻底解耦的纯脚本架构，支持在 Root 管理器中一键热重载，并通过 WebUI 完成安全配置与启用控制。

**创作者:** UncookedBoot (大海兲)  
**协议:** GPLv3  
**兼容性:** KernelSU / Magisk / APatch 

---

## 🇨🇳 中文说明

### 💡 核心原理 (How it Works)

本模块采用现代化的脚本式模块架构：
* **Script-Only 架构:** 不依赖传统 Magic Mount，对深度定制系统更友好。
* **安装即读取，不默认接管:** 安装阶段会自动读取当前设备的 ZRAM 与 VM 参数，写入配置文件，但默认保持未启用状态。
* **WebUI 启用控制:** 用户在 WebUI 中保存配置后，模块才会开始在开机后自动应用。
* **热重载执行链:** 支持通过 Root 管理器的 Action 按钮立即应用当前配置，无需重启设备。
* **安全保护:** ZRAM 容量不得超过物理内存上限，前端与脚本端均会执行参数校验。
* **开机通知:** 当模块已启用时，开机自动应用成功或失败会发送系统通知。

### 🚀 使用指南

**1. 初始部署**  
在 Releases 页面下载 `.zip` 刷机包，通过 KernelSU/Magisk/APatch 刷入。安装终端会显示当前设备的物理内存、ZRAM 容量、压缩算法以及 VM 参数，并生成初始化配置。

**2. 默认状态**  
模块安装后默认 **未启用**，不会主动修改当前系统的 ZRAM。此时配置文件只作为当前设备状态的快照。

**3. WebUI 配置与启用**  
进入模块 WebUI 后，可直接输入 ZRAM 容量（单位 GB），也可以使用 **1/2、1/3、1/4 物理内存** 快捷选项。保存后会写入配置并启用模块，后续开机自动应用生效。

**4. 立即应用**  
保存配置后，可点击 Root 管理器中的 **Action** 按钮立即执行当前配置；若不手动执行，则会在下次开机延迟应用。

### ✅ v1.5 更新日志

* 新增安装阶段设备当前配置读取，并在终端打印物理内存与现有 ZRAM/VM 参数。
* 新增 `ENABLED` 启用开关，安装后默认不接管，只有 WebUI 保存后才启用。
* 新增开机自动应用结果通知，成功与失败均可在系统通知中看到反馈。
* 新增核心安全校验：ZRAM 容量不能超过物理内存，脚本与 WebUI 双重拦截非法参数。
* 新增 WebUI 快捷容量按钮：`1/2`、`1/3`、`1/4` 物理内存，同时保留手动输入 GB。
* 优化手动 Action 行为：未启用时只提示，不执行底层修改。
* 优化核心脚本容错：当前未启用 zram swap 时会跳过 `swapoff`，避免无意义失败。

### ⚠️ 用户须知
* **容量限制:** 出于安全考虑，ZRAM 目标值不得超过设备物理内存整数 GB 上限。
* **启用方式:** 安装后不会自动接管，需先在 WebUI 保存一次配置。
* **冲突说明:** 若设备中存在持续轮询并强制锁定 ZRAM 的其他守护进程，本模块的应用结果可能被覆盖。
* **免责声明:** 修改 Linux 内核底层节点具有一定风险。作者不对因极端内存调度导致的设备卡顿、数据丢失或重启负责。

---

## 🇬🇧 English Version

### 💡 Principles (How it Works)

This module uses a modern script-only architecture:
* **Script-Only Design:** No traditional Magic Mount dependency, making it friendlier to customized ROM environments.
* **Read Current State on Install:** During installation, the module reads the current ZRAM and VM settings and writes them into the config file, but stays disabled by default.
* **WebUI-Based Enablement:** The module only starts taking control after the user saves settings in the WebUI.
* **Hot Reload via Action:** Users can apply the current configuration immediately with the Root Manager Action button.
* **Safety Validation:** Target ZRAM size must not exceed physical memory; both the WebUI and shell script validate parameters.
* **Boot Notification:** When enabled, automatic boot-time apply will post a success or failure notification.

### 🚀 Usage Guide

**1. Installation**  
Download the release `.zip`, flash it via KernelSU/Magisk/APatch, and review the installer output for physical memory, current ZRAM size, compression algorithm, and VM parameters.

**2. Default State**  
After installation, the module is **disabled by default** and does not modify the current ZRAM setup until the user explicitly enables it.

**3. Configure and Enable via WebUI**  
Open the WebUI and either enter a ZRAM size in GB directly or use the **1/2, 1/3, 1/4 of physical memory** shortcuts. Saving the form writes the config and enables automatic boot-time apply.

**4. Apply Immediately**  
After saving, use the Root Manager **Action** button to apply the config immediately, or just reboot and let the module apply it automatically after boot.

### ✅ v1.5 Changelog

* Added install-time detection of current device memory, ZRAM size, compression algorithm, and VM parameters.
* Added an `ENABLED` flag so the module stays disabled by default until the user saves settings in the WebUI.
* Added boot-time notification feedback for successful or failed automatic apply.
* Added safety checks so target ZRAM size cannot exceed physical memory, enforced in both the WebUI and shell script.
* Added WebUI quick size buttons for `1/2`, `1/3`, and `1/4` of physical memory while keeping direct GB input.
* Improved Action behavior so disabled configs only show guidance instead of performing low-level changes.
* Improved script tolerance by skipping `swapoff` when zram swap is not currently active.

### ⚠️ Notes
* **Capacity Limit:** For safety, the target ZRAM size must not exceed the device's physical memory in whole GB.
* **Enablement:** The module will not take control until the user saves a config in the WebUI.
* **Conflict Warning:** Other performance daemons may override the applied ZRAM size later.
* **Disclaimer:** Low-level kernel changes always carry risk; the author is not responsible for instability, lag, or data loss.