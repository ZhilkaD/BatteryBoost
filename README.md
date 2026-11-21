# BatteryBoost for Realme GT Neo 5 SE (RMX3700 / RMX3701)

<p align="center">
  <img src="https://img.shields.io/badge/Version-v3.0.0-00C853?style=for-the-badge&logo=android" alt="Version 3.0.0" />
  <img src="https://img.shields.io/badge/Device-RMX3700%20%7C%20RMX3701-007ACC?style=for-the-badge&logo=oppo" alt="Device" />
  <img src="https://img.shields.io/badge/SoC-Snapdragon%207%2B%20Gen%202%20(SM7475)-FF8F00?style=for-the-badge&logo=qualcomm" alt="Snapdragon 7+ Gen 2" />
  <img src="https://img.shields.io/badge/Root-KernelSU%20%7C%20Magisk%20%7C%20APatch-9C27B0?style=for-the-badge" alt="Root Supported" />
  <img src="https://img.shields.io/badge/Android-15%20%7C%2016%20%7C%2017-455A64?style=for-the-badge" alt="Android Versions" />
</p>

---

## ⚡ Overview

**BatteryBoost** is a surgical power-optimization, scheduler-tuning, and telemetry-suppression module built specifically for **Realme GT Neo 5 SE** (`RMX3700`, `RMX3701`, `RE585F`, `RE58D1L1` / `senna_jr`).

Unlike generic battery modules that blindfold governors or throttle devices into stuttering, **BatteryBoost v3.0 is built on empirical live measurements** on stock firmware (`16.0.5.1010(EX01)`). Every single value was tested before and after:
* **238 parameters applied** (237 OK, 0 critical failures).
* **Work with vendor strengths**: Stock UFS auto-hibernation, clock-gating, Wi-Fi sleep, and suspend are already optimal and left untouched.
* **Neutralize vendor bugs**: Subsystem memory dumpers, aggressive wakeups on touch, continuous telemetry spam, and GPU sleep blocks are eliminated at the root.

---

## 📊 Live Device Measurements & Telemetry

| Metric / Scenario | Stock Behavior | BatteryBoost v3.0 | Real-World Impact |
| :--- | :--- | :--- | :--- |
| **Deep Sleep Drain** | 2–3% / 8 hours (sporadic wakeups) | **5% over 18 hours** | **~0.27%/hour** idle drain |
| **Idle Sleep Current** | Spikes up to 180–300 mA | **6 – 53 mA** steady | Ultra-low standby draw |
| **Memory Buses (DDR / LLCC / L3)** | Frequent unneeded escalations | Rock-solid minimum clock in idle | Saves significant SoC base power |
| **Touch Input Reaction** | Wakes Prime core (`cpu7`) to **1996 MHz** | Wakes only Silver & Gold (`cpu0-6`) | Zero touch jank, no Prime spikes |
| **Audio Offload Buffer** | 32 KB (wakes CPU every ~100ms) | **256 KB** (8x buffer capacity) | **8x fewer CPU wakeups** during music |
| **OPlus Telemetry** | `ostatsd`, `pullerd`, `tpd`, `midasd` active | **All 5 daemons neutralized via vendor trigger** | Zero background analytics overhead |
| **GPU Sleep (`force_no_nap`)** | Stuck at `1` (GPU prevented from nap) | **Enforced `0` with recovery daemon** | Adreno 725 collapses into low-power states |
| **CPU Throttling Test** | ~289 GIPS (dips sharply upon heating) | **289 max / 274 avg / 241 min GIPS** | Sustained throughput without thermal crash |

---

## 🧠 Key Features & Architectural Highlights

### 1. SmartBoost: Screen-Gated Adaptive Load Engine
Previous versions used blunt caps or unbounded triggers. **SmartBoost v3.0** introduces a precise, dual-window load detector:
* **Dual Metrics:**
  * **GPU Busy Ratio:** Evaluates `gpubusy` delta over 15-second windows (triggers at $\ge 20\%$).
  * **Big Cluster CPU Utilization:** Reads `/proc/stat` delta across cores `cpu4–7` (triggers at $\ge 70\%$).
* **Screen State Gating (`mWakefulness`):** Detects panel state directly from the Android power subsystem. If the screen is Off or in AOD (`Asleep`/`Dozing`), SmartBoost is strictly locked to battery mode. Background GPU rendering will **never** trigger clock boosts.
* **Single-Tier Prime Release:** 
  * Under heavy load, only the **Prime Cortex-X2** core is released to **2918.4 MHz**.
  * The Gold cluster remains capped at **2112.0 MHz**. 
  > *Empirically proven:* Uncapping both Gold and Prime simultaneously caused fast thermal accumulation, triggering Qualcomm's aggressive thermal engine and resulting in *lower* sustained GIPS (259 vs 289 GIPS).

### 2. OPlus Telemetry Neutralization (Root Level)
Stock OPlus ROMs spawn multiple telemetry and diagnostic loggers that wake the device repeatedly:
* **The Root Fix:** Rather than waging an endless daemon kill-loop, BatteryBoost flips the internal vendor trigger via `persist.sys.midas_ostats.restriction=1`.
* Completely stops and disables:
  * `ostatsd` (CPU analytics)
  * `ostats_pullerd`
  * `ostats_tpd`
  * `midasd`
  * `vendor.ss_ramdump` (subsystem ramdump collection)
* **Bluetooth HCI Logging:** Disabled (`persist.sys.oplus.bt.cache_hcilog_mode=0`), stopping up to 100 MB of diagnostic dumps writing to internal flash.
* **Doze Lockdown:** Stripped `com.heytap.pictorial` (lockscreen wallpaper downloader) from the system Doze whitelist.

### 3. CPU, WALT & Scheduler Refinements
* **Silver (Cortex-A510):** `adaptive_low_freq` synced with hardware floor (300 MHz), hispeed frequency capped at 940.8 MHz, target load increased to 85.
* **Gold (Cortex-A715):** Steady-state max frequency capped to 2112 MHz (saving noticeable power vs stock 2496 MHz peak while preserving fluidity). Core activation threshold raised to 4 concurrent tasks.
* **Prime (Cortex-X2):** Steady-state cap set to 2361.6 MHz (stock idle drifted up to 2707 MHz). Releases to 2918.4 MHz only when SmartBoost detects sustained heavy workloads.
* **WALT Conservative Forecasting:** `sched_conservative_pl=1` prevents transient micro-tasks from spiking CPU clusters into high-frequency steps.

### 4. Background Guardian Daemons
* **Fast Daemon (15s):** Guards GPU nap, Core Control thresholds, clamp values, Input Boost frequencies, and SmartBoost state transitions against vendor ORMS resets.
* **Slow Daemon (120s):** Periodic surveillance over DDR/LLCC bus parameters, swappiness, and persistent vendor telemetry revive checks.
* **NAP0 Daemon:** First 3 minutes of boot, verifies `force_no_nap=0` every 10 seconds.
* **IRQ Daemon:** Automatically redirects WiFi interrupts (`pci0_wlan_ce_*`, `wlan_wake_irq`) to energy-efficient Silver cores (`0f`).

### 5. Non-Intrusive `[BATT]` Sampler
Integrated directly into the survival daemon log. Every 60 seconds, it appends a compact health status:
```text
[BATT] up=12450s cap=87 cur=-142000 temp=310 gold=1440000/2112000 prime=787200 boost=0
```
Allows real-time verification of charging, discharging current ($\mu A$), thermal state, and active frequencies without third-party battery drainers.

---

## 🧹 What Was Removed in v3.0 (Anti-Battery & Dead Code)

| Tweak / Parameter | Previous State | v3.0 Status | Reason |
| :--- | :--- | :--- | :--- |
| `tcp_keepalive_time` | Lowered to 1800s | **Removed (Stock 7200s)** | Lowering keepalive woke cellular/Wi-Fi radio 4x more often in standby. |
| `sched_pelt_multiplier` | Set to 4 | **Removed (Stock 1)** | Forced Silver cores to 1804.8 MHz during simple video playback. |
| `sched_many_wakeup_threshold` | Set to 3 | **Removed** | Scattered wakeups across unrelated cores instead of packing. |
| `sched_group_downmigrate` | Set to 85 | **Removed** | Kept task groups pinned to power-hungry Big cores too long. |
| `Silver scaling_min` | Forced to 300 MHz | **Removed** | Vendor perf engine continuously rejected it, causing CPU churn. |
| UFS Storage Tunables | Re-writing hibern8/clkgate | **Removed** | Stock EX01 already defaults to `5000/1/1`; previous code was redundant. |
| Display No-Ops | Overwriting VRR/QSync props | **Removed** | Stock firmware already handles these properly. |

---

## 🛠️ Installation & Updating

> [!WARNING]
> **Dirty updates over v2.x are NOT supported.** Old configurations, legacy scripts, or lingering bind-mounts can interfere with v3.0's architecture.

### Clean Installation Procedure:
1. **Remove** previous BatteryBoost module in KernelSU / Magisk / APatch.
2. **Reboot** the device.
3. **Flash** `BatteryBoost_GTNeo5SE_v3.0.zip`.
4. **Reboot** and allow the system 3–4 minutes to settle.

### Clean Uninstall:
Disable or remove the module via your root manager and reboot. The included `uninstall.sh` automatically restores all `persist.*` properties, re-whitelists stock Doze services, and purges logs.

---

## 🔍 Verification & Diagnostics

To check the operational log on your phone via Termux or ADB:
```bash
su -c "cat /data/local/tmp/batteryboost.log"
```

To live-monitor SmartBoost and power transitions:
```bash
su -c "tail -f /data/local/tmp/batteryboost.log | grep -E 'SmartBoost|BATT|Fixed'"
```

---

## 👤 Author & Acknowledgments

* **Developer:** [ZhilkaD](https://github.com/ZhilkaD)
* **Target Device:** Realme GT Neo 5 SE (`RMX3700` / `RMX3701` / `RE585F`)
