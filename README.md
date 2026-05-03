# ZRAM-Dynamic-Control
⚡ A script-only, hot-reloadable ZRAM dynamic controller for modern Android devices (KernelSU/Magisk).

# ZRAM Dynamic Control (ZRAM 动态控制核心)

🌍 *[English Version Below](#english-version)*

这是一个专为现代 Android 环境设计的轻量级 ZRAM 动态调度核心。采用彻底解耦的纯脚本架构，支持在 Root 管理器中一键热重载，并通过 WebUI 完成 MB 配置、立即执行、通知反馈与中英切换。

**创作者:** UncookedBoot (大海兲)  
**协议:** GPLv3  
**兼容性:** KernelSU / Magisk / APatch 

---

## 🇨🇳 中文说明

### 💡 核心原理

本模块采用现代化的脚本式模块架构：
* **Script-Only 架构:** 不依赖传统 Magic Mount，对深度定制系统更友好。
* **安装即读取，不默认接管:** 安装阶段自动读取设备当前 ZRAM 与 VM 参数，写入配置文件，但默认保持未启用状态。
* **MB 配置同步 Scene:** 配置主字段改为 `ZRAM_SIZE_MB`，并按 Scene 最后公开版的核心策略执行 ZRAM 调整。
* **Scene 同步策略:** 调整时保留 `backing_dev`、设置 `max_comp_streams=4`，并按 Scene 规则决定是写字节数还是 `M` 单位。
* **WebUI 直接执行:** WebUI 支持保存配置并立即触发核心脚本，无需返回 Root 管理器再点 Action。
* **统一通知:** 开机自动应用、Root 管理器 Action 与 WebUI 立即执行，都会在每次实际尝试生效后发送系统通知。
* **中英切换:** WebUI 右上角提供 `🌐` 按钮，可在中文和英文界面之间切换。
* **安全保护:** ZRAM 容量不得超过物理内存 MB 上限，前端与脚本端双重校验。

### 🚀 使用指南

**1. 初始部署**  
在 Releases 页面下载 `.zip` 刷机包，通过 KernelSU/Magisk/APatch 刷入。安装终端会显示当前设备的物理内存 MB、当前 ZRAM MB、压缩算法以及 VM 参数，并生成初始化配置。

**2. 默认状态**  
模块安装后默认 **未启用**，不会主动修改当前系统的 ZRAM。此时配置文件仅保存当前设备状态快照。

**3. WebUI 配置与立即生效**  
进入模块 WebUI 后，直接填写目标 `ZRAM 容量 (MB)`，再设置压缩算法、Swappiness 与 Watermark Scale。点击 **保存并立即执行** 后，会写入配置、启用模块并立刻调用核心脚本尝试生效。点击右上角 `🌐` 可切换中英界面。

**4. 其他执行方式**  
Root 管理器中的 **Action** 按钮仍可用；若不手动执行，则会在下次开机延迟自动应用。

### ✅ v1.6.2 更新日志

* 配置主字段从 `ZRAM_SIZE_KB` 切换为 `ZRAM_SIZE_MB`，并兼容读取旧的 KB / GB 配置。
* ZRAM 调整策略按 Scene 最后公开版同步：保留 `backing_dev`、设置 `max_comp_streams=4`、并在大容量时使用 `M` 单位写入 `disksize`。
* WebUI 输入单位改为 MB，并保留中英切换、保存并立即执行与即时结果回显。
* 开机路径在保持当前未启用默认语义的前提下，按 Scene 逻辑处理 ZRAM resize 的关键细节。
* 本地打包、提交、推送并确保云端 release 与本地源码一致。

### ⚠️ 用户须知
* **容量限制:** ZRAM 目标值必须小于或等于设备物理内存 MB 上限。
* **启用方式:** 安装后不会自动接管；需通过 WebUI 保存并立即执行，或先保存后等待下次开机应用。
* **冲突说明:** 若设备中存在持续轮询并强制锁定 ZRAM 的其他守护进程，本模块的应用结果可能被覆盖。
* **免责声明:** 修改 Linux 内核底层节点具有一定风险。作者不对因极端内存调度导致的设备卡顿、数据丢失或重启负责。

---

## 🇬🇧 English Version

### 💡 Principles

This module uses a modern script-only architecture:
* **Script-Only Design:** No traditional Magic Mount dependency, making it friendlier to customized ROM environments.
* **Read Current State on Install:** During installation, the module reads the current ZRAM and VM settings into the config file but stays disabled by default.
* **MB Config Aligned with Scene:** The main capacity field is now `ZRAM_SIZE_MB`, and the resize flow follows the core strategy from the last open-source Scene implementation.
* **Scene Resize Strategy:** The module preserves `backing_dev`, sets `max_comp_streams=4`, and writes `disksize` using either raw bytes or `M` units depending on the size.
* **Direct WebUI Execution:** The WebUI can save the config and immediately invoke the core script without returning to the Root Manager Action page.
* **Unified Notifications:** Boot auto-apply, Root Manager Action, and WebUI immediate apply all post a system notification after each real apply attempt.
* **Language Toggle:** The WebUI includes a `🌐` button in the top-right corner to switch between Chinese and English.
* **Safety Validation:** Target ZRAM size must not exceed the physical-memory limit in MB, enforced by both the WebUI and shell script.

### 🚀 Usage Guide

**1. Installation**  
Download the release `.zip`, flash it via KernelSU/Magisk/APatch, and review the installer output for physical memory in MB, current ZRAM in MB, compression algorithm, and VM parameters.

**2. Default State**  
After installation, the module is **disabled by default** and does not modify the current ZRAM setup until you save and execute a config.

**3. Configure and Apply from the WebUI**  
Open the WebUI, enter the target `ZRAM size (MB)`, adjust the algorithm and VM parameters, then press **Save and Apply Now** to write the config, enable the module, and immediately trigger the core script. Use the `🌐` button to switch the page language.

**4. Other Execution Paths**  
The Root Manager **Action** button still works, and the module can also apply automatically after the next boot delay.

### ✅ v1.6.2 Changelog

* Switched the main config field from `ZRAM_SIZE_KB` to `ZRAM_SIZE_MB`, while keeping backward compatibility with old KB / GB configs.
* Synced the ZRAM resize strategy with the last open-source Scene implementation: preserve `backing_dev`, set `max_comp_streams=4`, and use `M`-unit writes for large sizes.
* Updated the WebUI to use MB input while keeping the language toggle, save-and-apply flow, and immediate output display.
* Kept the current disabled-by-default behavior while aligning the key boot-time resize details with Scene.
* Repacked, committed, pushed, and kept the local source aligned with the cloud release.

### ⚠️ Notes

* **Capacity Limit:** The target ZRAM size must be less than or equal to the device physical-memory limit in MB.
* **Enablement:** The module will not take control until a config is saved and executed.
* **Conflict Warning:** Other performance daemons may still override the applied ZRAM size later.
* **Disclaimer:** Low-level kernel changes always carry risk; the author is not responsible for instability, lag, or data loss.