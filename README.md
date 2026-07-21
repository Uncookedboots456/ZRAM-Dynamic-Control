# ZRAM Dynamic Control

Android ZRAM controller for KernelSU, Magisk, and APatch. Version 1.7 adds safe cooperation with Scene's ZRAM controller instead of letting two modules write the same kernel nodes.

## 中文

### 功能

- WebUI 保存 `ZRAM_SIZE_MB`、压缩算法、Swappiness 与 Watermark Scale。
- OnePlus/OPlus 设备优先使用系统声明的物理内存容量，避免内核保留区导致 16GB 被误报为约 15GB。
- 普通模式下由模块应用配置；安装后默认不接管现有 ZRAM。
- 检测到已启用的 Scene ZRAM 控制器时，本模块不写 ZRAM sysfs、不重建 swap；开机早期原子更新 `/data/swap_config.conf`，Scene 完成后仅补写 VM 参数。
- 开机在 Scene 模式下校验实际值，并通过系统通知报告成功或失败。
- 校验容量、数值范围和内核实际支持的压缩算法；配置写入采用临时文件原子替换。

### 安装与使用

1. 在 Releases 下载 ZIP，通过 KernelSU、Magisk 或 APatch 安装。
2. 在管理器中打开模块 WebUI，填写目标参数后点击 **保存**。
3. 未使用 Scene 时，可点击 **执行 action** 立即应用；使用 Scene 时会显示 `SCENE_DEFERRED=1`，表示配置已交给 Scene，运行态保持不被本模块直接修改。
4. 重启后查看系统通知；也可检查 `/data/swap_config.conf` 与 `/sys/block/zram0/`。

### Scene 共存边界

Scene 已启用时，Scene 是唯一的 ZRAM 生命周期写入者。本模块只负责配置同步、延迟补写 VM 参数、开机校验和通知。这避免两个控制器同时 `swapoff` 或重建 ZRAM。

### v1.7.0

- 新增 Scene 协作模式与开机校验通知。
- 修复 SukiSU WebUI 多行桥接输出截断：配置读取改为单行序列化。
- 修复 WebUI 写入：使用单行原子 `printf` 写入，不依赖 heredoc。
- 修复写后校验的布尔/字符串类型比较错误。
- 修复 MMRS 安装路径解析，并使用 KernelSU BusyBox 文件锁。
- 已在 Android 16 / SukiSU Ultra 4.1.3 / Scene 4.2.4 真机验证保存、Scene 同步、action 延迟应用和开机通知。

### v1.7.1

- 修复 OPlus 物理内存识别、Scene Writeback `+4096MB` 校验和开机配置同步时序。
- Scene 完成后补写 VM 参数，避免 OPlus 收尾动作覆盖 Swappiness。

## English

### What it does

- Saves ZRAM size, compression algorithm, swappiness, and watermark scale from a WebUI.
- Uses the declared physical RAM size on OPlus devices instead of the kernel-reserved total.
- Applies settings directly when it is the only controller.
- When Scene's ZRAM controller is active, it never writes ZRAM sysfs nodes or rebuilds swap. It syncs `/data/swap_config.conf` early and only reasserts VM parameters after Scene finishes.
- Verifies the applied Scene values at boot and posts a best-effort system notification.

### v1.7.0

- Added Scene cooperative mode and boot verification notifications.
- Fixed SukiSU WebUI bridge compatibility for config reads, atomic writes, and post-write verification.
- Verified on Android 16 with SukiSU Ultra 4.1.3 and Scene 4.2.4.

### v1.7.1

- Fixed OPlus RAM detection, Scene writeback size verification, early config sync, and late VM parameter overrides.

## Safety

Changing low-level memory settings can cause lag or instability. Keep one ZRAM controller enabled at a time; if Scene is detected, this module intentionally delegates runtime application to Scene.

## License

GPL-3.0. See [LICENSE](LICENSE).
