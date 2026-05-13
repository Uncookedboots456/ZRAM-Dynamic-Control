# ZRAM Dynamic Control: Current Code, Bugs, and Project Summary

## Overview

This project is a standalone Android ZRAM control module for KernelSU / Magisk / APatch.

Current design goals:

- No MetaModule dependency
- Native module boot apply through the module's own `service.sh`
- WebUI-driven configuration
- Script-only runtime behavior
- Save-first and run-now control flow
- English notification support for shell apply success

The module reads and writes ZRAM-related settings, persists them in `config.conf`, and applies them through `zram_ctrl.sh`.

---

## Current Code Files

### `module.prop`

Purpose:

- Declares module identity and version metadata for the Android module manager

Current role:

- Module id: `zram_12g_uncookedboot`
- Test package version: `test1.6.4`
- Version code: `16`

Notes:

- This file does not contain runtime logic
- It must stay aligned with packaged test builds

### `config.conf`

Purpose:

- Persistent runtime configuration storage

Current keys:

- `ENABLED`
- `ZRAM_SIZE_MB`
- `COMP_ALGORITHM`
- `SWAPPINESS`
- `WATERMARK_SCALE_FACTOR`

Notes:

- `ZRAM_SIZE_MB` is the canonical size field
- Older `KB` and `GB` config formats are still read by shell and WebUI compatibility logic
- This file is initialized at install time and later overwritten by WebUI save

### `customize.sh`

Purpose:

- Install-time initialization script

Current behavior:

- Reads current device memory size
- Reads current ZRAM disksize
- Reads current compression algorithm
- Reads current VM tunables
- Writes a snapshot into `config.conf`
- Sets executable permissions on `service.sh` and `zram_ctrl.sh`

Important constraint:

- This is one-time initialization at install/flash time
- It should not be treated as the source of the reopen/save bug

### `service.sh`

Purpose:

- Boot-time apply entrypoint

Current behavior:

- Waits for `sys.boot_completed=1`
- Sleeps `30` seconds after boot completion
- Checks `ENABLED=1`
- Executes `zram_ctrl.sh`

Design intent:

- Native module-owned boot path
- No MetaModule compatibility layer
- No parent-module loader dependency

### `zram_ctrl.sh`

Purpose:

- Main shell engine that validates and applies ZRAM settings

Current behavior:

- Reads config values from `config.conf`
- Supports canonical `MB` reads and compatibility fallback from `KB` / `GB`
- Validates:
  - config exists
  - module enabled
  - target ZRAM is a positive integer
  - target ZRAM does not exceed physical memory
  - algorithm is supported
  - swappiness range is valid
  - watermark scale is valid
- Applies:
  - drop caches
  - swapoff if needed
  - zram reset
  - compression algorithm
  - disksize
  - mkswap
  - swapon
  - VM tunables

Notification behavior:

- Success title: `ZRAM applied`
- Failure title: `ZRAM apply failed`
- Best-effort notification path:
  - `cmd notification post`
  - fallback `log`

Important note:

- Notification failure should not fail the ZRAM apply itself

### `webroot/index.html`

Purpose:

- WebUI for user configuration and immediate execution

Current UI behavior:

- Input fields:
  - ZRAM size in MB
  - compression algorithm
  - swappiness
  - watermark scale
- Two-button flow:
  - `Save`
  - `Run action`
- Terminal-like output pane
- Chinese / English toggle

Current logic areas:

- Reads memory limit from `/proc/meminfo`
- Reads persisted config with `ksu.exec`
- Parses config text
- Validates input before save/run
- Writes config
- Reloads config from disk after save
- Verifies persisted values match requested values
- Executes `zram_ctrl.sh` on `Run action`

Recent changes:

- Removed silent whole-file fallback to `1024`
- Added persisted-config normalization
- Added save-after-readback verification
- Replaced heredoc write with single-command `printf` write
- Expanded `ksu.exec` result parsing to combine `stdout`, `stderr`, `output`, `message`, and `result`

### `README.md`

Purpose:

- Project documentation

Current value:

- Describes intended architecture and usage flow
- Explains save/apply design, notifications, terminal output, and compatibility expectations

Important caveat:

- README reflects intended behavior, not guaranteed actual behavior on every KSU WebUI runtime

---

## Runtime Flow

### Install flow

1. Module is flashed
2. `customize.sh` snapshots current system state into `config.conf`
3. Module remains disabled by default with `ENABLED=0`

### WebUI save flow

1. User enters values in WebUI
2. Frontend validates values
3. Frontend writes `config.conf`
4. Frontend immediately reads `config.conf` back
5. Frontend verifies persisted values match user input
6. UI updates status and terminal output

### WebUI run flow

1. User clicks `Run action`
2. Save flow runs first
3. If save verification passes, frontend runs `zram_ctrl.sh`
4. Shell engine applies settings
5. Shell engine sends best-effort English notification

### Boot flow

1. `service.sh` waits for boot completion
2. `service.sh` sleeps `30s`
3. `service.sh` checks `ENABLED`
4. `service.sh` runs `zram_ctrl.sh`

---

## Known Bugs and Risks

### 1. WebUI readback still fails on some real KSU environments

Observed symptom:

- `config.conf` is actually updated on disk
- WebUI still reports:
  - `Saved ZRAM size is missing or invalid.`

Current understanding:

- The write path is no longer the primary suspect
- The remaining likely issue is KSU WebUI runtime variability in the `ksu.exec()` return object or returned text formatting
- Even after broadening output parsing, some environments may still wrap or transform command output in a way the current parser does not fully handle

Impact:

- Save can succeed physically but fail logically in UI
- `Run action` can be blocked by frontend verification even though disk state is correct

Likely next debugging step:

- Print the raw `ksu.exec("cat config.conf")` result object directly into the terminal output
- Capture the exact structure from the target device
- Adjust `normalizeExecResult()` and/or `readPersistedConfig()` based on the real object shape

### 2. `.github/workflows/build.yml` is still included in packaged ZIP

Observed symptom:

- The test flashable ZIP includes `.github/workflows/build.yml`

Impact:

- No runtime impact on the device
- Packaging is not clean for release use

Resolution path:

- Exclude `.github` from future release packaging

### 3. Frontend verification is stricter than shell reality

Observed behavior:

- Frontend requires immediate readback and exact match
- Shell apply logic itself only depends on `config.conf`

Risk:

- Frontend can block the user even when shell-side config is already valid

Tradeoff:

- Strict verification catches real persistence bugs
- It can also reject valid saves if KSU WebUI returns config text inconsistently

Possible future adjustment:

- Keep strict mode for debugging builds
- Add a fallback mode that trusts successful write if file exists and shell-side apply passes

---

## Project Understanding

This module is fundamentally a small Android control plane with three layers:

### Layer 1: Persistent state

- `config.conf`

This is the only real source of truth for saved user configuration.

### Layer 2: Apply engine

- `zram_ctrl.sh`
- `service.sh`

These scripts are the actual runtime path that changes system behavior.

### Layer 3: User control surface

- `webroot/index.html`

This is a convenience layer for editing and triggering the engine. It should not invent state independently of `config.conf`.

The architecture is sound if these constraints hold:

- WebUI writes exactly what shell later reads
- WebUI reads exactly what shell wrote
- Boot path is owned by the module itself
- No MetaModule compatibility or loader hacks are introduced

The current problem is not the shell engine. The shell engine and boot path are structurally straightforward. The unstable area is the WebUI-to-KSU execution boundary.

---

## Summary of Implemented Changes

Implemented so far:

- Switched boot delay from `60s` to `30s`
- Kept standalone native `service.sh` boot path
- Changed shell notifications to English
- Made shell notifications best-effort
- Removed WebUI silent fallback to `1024`
- Added save-after-readback verification
- Replaced heredoc config write with `printf`-based write
- Expanded `ksu.exec()` output normalization
- Repacked module as `test1.6.4`

Not fully resolved yet:

- Device-specific WebUI readback failure after successful physical save

---

## Recommended Next Step

The next correct move is not another blind parser tweak.

The correct debugging action is:

1. Add a temporary debug mode in `index.html`
2. Dump the raw `ksu.exec("cat config.conf")` return object to the terminal pane
3. Reproduce on the target device
4. Adapt parsing to the exact object shape actually returned by that KSU build

That will convert the current issue from guesswork into a deterministic compatibility fix.
