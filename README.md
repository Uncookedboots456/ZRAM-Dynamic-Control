# ZRAM-Dynamic-Control
⚡ A script-only, hot-reloadable ZRAM dynamic controller for modern Android devices (KernelSU/Magisk).

# ZRAM Dynamic Control (ZRAM 动态控制核心)

🌍 *[English Version Below](#english-version)*

这是一个专为现代 Android 环境设计的轻量级 ZRAM 动态调度核心。采用彻底解耦的纯脚本架构，并在 `v1.6.3` 回到旧逻辑基线后，通过 WebUI 完成 MB 配置、保存/执行分离、仿终端输出、通知反馈与中英切换。

**创作者:** UncookedBoot (大海兲)  
**协议:** GPLv3  
**兼容性:** KernelSU / Magisk / APatch 

---

## 🇨🇳 中文说明

### 💡 核心原理

本模块采用现代化的脚本式模块架构：
* **Script-Only 架构:** 不依赖传统 Magic Mount，对深度定制系统更友好。
* **安装即读取，不默认接管:** 安装阶段自动读取设备当前 ZRAM 与 VM 参数，写入配置文件，但默认保持未启用状态。
* **MB 配置:** 配置主字段为 `ZRAM_SIZE_MB`，同时兼容读取旧版 `KB / GB` 配置。
* **WebUI 双按钮交互:** WebUI 分为 `📦 保存` 与 `🚀 执行 action` 两个动作；保存只写入配置，执行 action 会保存后再立刻触发核心脚本。
* **统一通知:** 开机自动应用与 WebUI `🚀 执行 action`，都会在每次实际尝试生效后发送系统通知。
* **中英切换:** WebUI 右上角新增 `🌐` 按钮，可在中文和英文界面之间切换。
* **仿终端反馈:** WebUI 底部新增仿终端窗口，尽量贴近原脚本终端输出，并可随语言切换显示英文版。
* **实验性协议:** 新增 `lzo`、`lzo-rle`、`lz4k`、`zstdn`、`zstdn_o` 选项；若内核不支持，失败信息会直接显示在终端窗口。
* **安全保护:** ZRAM 容量不得超过设备物理内存的 MB 上限，前端与脚本端双重校验。

### 🚀 使用指南

**1. 初始部署**  
在 Releases 页面下载 `.zip` 刷机包，通过 KernelSU/Magisk/APatch 刷入。安装终端会显示当前设备的物理内存 MB、当前 ZRAM MB、压缩算法以及 VM 参数，并生成初始化配置。

**2. 默认状态**  
模块安装后默认 **未启用**，不会主动修改当前系统的 ZRAM。此时配置文件仅保存当前设备状态快照。

**3. WebUI 配置与执行**  
进入模块 WebUI 后，直接填写目标 `ZRAM 容量 (MB)`，再设置压缩算法、Swappiness 与 Watermark Scale。点击 **`📦 保存`** 会写入配置并启用模块；点击 **`🚀 执行 action`** 会保存当前配置后立刻调用核心脚本尝试生效。页面底部仿终端窗口会尽量按原终端格式显示本次运行输出，点击右上角 `🌐` 可切换中英界面。

**4. 其他执行方式**  
若不手动执行，则会在下次开机延迟自动应用。

### ✅ v1.6.3 更新日志

* 回到 `v1.6.1` 的旧逻辑基线，不再引入 Scene 相关策略。
* WebUI 操作拆分为 `📦 保存` 与 `🚀 执行 action`，并改为同一行左右分列。
* 页面下方新增仿终端窗口，执行输出尽量贴近原脚本终端内容。
* 终端输出现在也支持中英切换，英文模式下会显示对应英文日志。
* 新增实验性压缩协议选项：`lzo`、`lzo-rle`、`lz4k`、`zstdn`、`zstdn_o`。

### ⚠️ 用户须知
* **容量限制:** ZRAM 目标值必须小于或等于设备物理内存的 MB 上限。
* **启用方式:** 安装后不会自动接管；需通过 WebUI 保存配置并执行 action，或先保存后等待下次开机应用。
* **冲突说明:** 若设备中存在持续轮询并强制锁定 ZRAM 的其他守护进程，本模块的应用结果可能被覆盖。
* **免责声明:** 修改 Linux 内核底层节点具有一定风险。作者不对因极端内存调度导致的设备卡顿、数据丢失或重启负责。

---

## 🇬🇧 English Version

### 💡 Principles

This module uses a modern script-only architecture:
* **Script-Only Design:** No traditional Magic Mount dependency, making it friendlier to customized ROM environments.
* **Read Current State on Install:** During installation, the module reads the current ZRAM and VM settings into the config file but stays disabled by default.
* **MB Configuration:** The main capacity field is `ZRAM_SIZE_MB`, while older `KB / GB` configs remain readable for compatibility.
* **Two-Button WebUI Flow:** The WebUI now separates `📦 Save` and `🚀 Run action`. Save only writes the config, while Run action saves first and then executes the core script immediately.
* **Unified Notifications:** Boot auto-apply and the WebUI `🚀 Run action` path both post a system notification after each real apply attempt.
* **Language Toggle:** The WebUI now includes a `🌐` button in the top-right corner to switch between Chinese and English.
* **Terminal-Style Feedback:** A terminal-like output pane shows execution logs in a format close to the original shell output, with English rendering when the UI language is switched.
* **Experimental Algorithms:** Added `lzo`, `lzo-rle`, `lz4k`, `zstdn`, and `zstdn_o`; unsupported kernel behavior is shown directly in the terminal output.
* **Safety Validation:** Target ZRAM size must not exceed the device physical-memory limit in MB, enforced by both the WebUI and shell script.

### 🚀 Usage Guide

**1. Installation**  
Download the release `.zip`, flash it via KernelSU/Magisk/APatch, and review the installer output for physical memory in MB, current ZRAM in MB, compression algorithm, and VM parameters.

**2. Default State**  
After installation, the module is **disabled by default** and does not modify the current ZRAM setup until you save and execute a config.

**3. Configure and Run from the WebUI**  
Open the WebUI, enter the target `ZRAM size (MB)`, adjust the algorithm and VM parameters, then press **`📦 Save`** to write the config or **`🚀 Run action`** to save and immediately execute the core script. The terminal-like pane at the bottom shows the current run output, and the `🌐` button switches both the UI and terminal rendering language.

**4. Other Execution Paths**  
The module can still apply automatically after the next boot delay.

### ✅ v1.6.3 Changelog

* Returned to the pre-Scene logic baseline based on `v1.6.1`.
* Split the WebUI actions into `📦 Save` and `🚀 Run action`, shown side by side.
* Added a terminal-style output pane that stays close to the original shell output format.
* Extended terminal rendering to English when the UI language is switched.
* Added experimental compression options: `lzo`, `lzo-rle`, `lz4k`, `zstdn`, and `zstdn_o`.

### ⚠️ Notes

* **Capacity Limit:** The target ZRAM size must be less than or equal to the device physical-memory limit in MB.
* **Enablement:** The module will not take control until a config is saved and executed.
* **Conflict Warning:** Other performance daemons may still override the applied ZRAM size later.
* **Disclaimer:** Low-level kernel changes always carry risk; the author is not responsible for instability, lag, or data loss.
