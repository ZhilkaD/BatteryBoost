# BatteryBoost for Realme GT Neo 5 SE (RMX3700 / RE585F)

Advanced power optimization and scheduler tuning module for **KernelSU** and **Magisk**. Designed for recent builds (Android 15/16) to eliminate idle drain, reduce thermal throttling under basic tasks, and optimize WALT/CPU behavior without dropping UI responsiveness.

---

## Technical Specifications & Features

### CPU & WALT Tuning
* **ORMS Neutralization:** Complete bypass using a bind-mount stub (`orms_stub`).
* **WALT Conservative Profile:** Enabled `sched_conservative_pl=1`. Uses conservative load forecasting for minor tasks (notifications, brief wakeups) to prevent unnecessary frequency spikes.
* **Core Efficiency:** * **Silver (LITTLE):** `need_cpus=0`, 50ms offline delay, `adaptive_low_freq` synchronized with hardware minimum (300MHz) for correct adaptive scaling.
  * **Gold (Big):** Migration threshold for the second Gold core raised to 4 tasks.
* **Overhead Reduction:** Disabled `sched_boost`, set `init_task_load=0` and `tunable_scaling=1`.

### Frequency Capping & Reapply Daemons
* **Early Caps (`post-fs-data.sh`):** Freq caps for Gold (2112000) and Prime (2707200) are enforced at the earliest boot stage to block early-boot power spikes before the main script execution.
* **Fast Daemon:** Background loop checking 10 key parameters every 15 seconds. Enforces CPU/GPU caps and LLCC/Stune tunables to counter aggressive stock overrides from `vendor.perf`.
* **Slow Daemon & Logging:** Periodic verification of `gpu_idle_timer=64` and LLCC parameters. Outputs explicit fixed entries to logs (e.g., `Fixed: gold_max_freq`).

### Memory Management
* **ZRAM Tuning:** Enforced `zstd` compression algorithm with `compaction` interval set to 20.
* **HybridSwap Integration:** Full compatibility with Realme's hybrid swap architecture. Optimizes `kswapd` behavior to minimize parasitic CPU overhead during memory reclaiming.

### Networking, I/O & IRQs
* **Network Stability:** Set `netdev_max_backlog=5000` to fix aggressive drop issues and eliminate packet loss/disconnects under load.
* **I/O Tweaks:** Enforced custom `rq_affinity` parameters and queue optimization across all `dm-` nodes.
* **Interrupt Filtering:** Stripped firmware-locked instances, `msm_irqbalance`, and redundant UFS IRQs. Cleaned Glink IRQ overhead to eliminate log spam.
* **Peripherals:** 5-second Wi-Fi autosuspend delay.

### Gaming Logic
* **Smart Boost:** Dynamic load detection. Automatically suspends all power limits during heavy gaming sessions to sustain maximum FPS, reapplying them instantly upon exit.

* 
[![Download](https://img.shields.io/github/v/release/ZhilkaD/BatteryBoost?label=Download%20ZIP&style=for-the-badge)](https://github.com/ZhilkaD/BatteryBoost/releases/latest)
