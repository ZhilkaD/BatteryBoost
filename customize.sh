#!/system/bin/sh
[ -z "$MODPATH" ] && MODPATH="${0%/*}"
command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
command -v abort    >/dev/null 2>&1 || abort()    { ui_print "ERROR: $1"; exit 1; }

ui_print ""
ui_print "======================================"
ui_print "  BatteryBoost GT Neo5 SE  v3.0.0"
ui_print "  RMX3700/RE585F | SM7475 | Android 16"
ui_print "======================================"
ui_print ""

DEV="$(getprop ro.product.device 2>/dev/null)"
MOD="$(getprop ro.product.model 2>/dev/null)"
AND="$(getprop ro.build.version.release 2>/dev/null)"
PLT="$(getprop ro.board.platform 2>/dev/null)"

ui_print "Device: $MOD ($DEV) | $PLT | Android $AND"
ui_print ""

case "$DEV" in
    RMX3700|RE58D1L1|RE585F) ui_print "[OK] Device Supported" ;;
    *) abort "Unsupported device: $DEV (need RMX3700/RE585F)" ;;
esac

[ "$AND" = "16" ] && ui_print "[OK] Android 16: clamp_min fix active"
[ "$PLT" != "taro" ] && ui_print "[!!] Platform $PLT (expected taro)"

ui_print ""
ui_print "-- Path check --"
_chk() { [ -e "$2" ] && ui_print "  [OK] $1" || ui_print "  [!!] $1 MISSING: $2"; }
_chk "Silver WALT"    "/sys/devices/system/cpu/cpufreq/policy0/walt"
_chk "Silver core_ctl" "/sys/devices/system/cpu/cpu0/core_ctl"
_chk "Gold WALT"      "/sys/devices/system/cpu/cpufreq/policy4/walt"
_chk "Prime WALT"     "/sys/devices/system/cpu/cpufreq/policy7/walt"
_chk "Gold core_ctl"  "/sys/devices/system/cpu/cpu4/core_ctl"
_chk "Prime core_ctl" "/sys/devices/system/cpu/cpu7/core_ctl"
_chk "GPU kgsl"       "/sys/class/kgsl/kgsl-3d0"
_chk "DDR DCVS"       "/sys/devices/system/cpu/bus_dcvs/DDR"
_chk "LLCC DCVS"      "/sys/devices/system/cpu/bus_dcvs/LLCC"
_chk "L3 DCVS"        "/sys/devices/system/cpu/bus_dcvs/L3"
_chk "Oplus display"  "/sys/kernel/oplus_display"
_chk "Oplus mem"      "/proc/oplus_mem"
_chk "Frame boost"    "/proc/oplus_frame_boost/stune_boost"
_chk "WALT proc"      "/proc/sys/walt"
_chk "/proc/interrupts" "/proc/interrupts"
_chk "PCIe power"     "/sys/bus/pci/devices/0000:01:00.0/power/control"

ui_print ""
ui_print "-- v3.0 COSMIC changes --"
ui_print "  P0: ORMS neutralized (bind-mount stub + stop fallback)"
ui_print "  P0b: oplus-omrg kernel ruler disabled (ruler_enable=0)"
ui_print "  P1: Silver need_cpus=0 (allow full offline, was 4)"
ui_print "  P2: Gold need_cpus=1 (minimum Gold online, was 3)"
ui_print "  P3: sched_boost=0 (kernel + WALT, was 1)"
ui_print "  P4: sched_tunable_scaling=1 (log scaling, was 0)"
ui_print "  P5: sched_init_task_load=0 0 (no new task bias)"
ui_print "  P6: Silver offline_delay 200->50ms (faster offline)"
ui_print "  P7: zram comp_algorithm lz4->zstd (better compression)"
ui_print "  P8: compaction_proactiveness 10->20 (less wakeups)"
ui_print "  P9: Thermal daemon (replaces ORMS thermal mgmt)"
ui_print "  P10: Daemons slowed (ORMS dead: 30s/60s/300s)"
ui_print "  P11: Removed NAP0 daemon (redundant with Fast)"
ui_print "  P12: Removed DDR/LLCC sample_ms (firmware-locked)"
ui_print "  P13: Removed msm_irqbalance stop"
ui_print "  P14: Removed UFS IRQ daemon (irqbalance handles it)"
ui_print "  P15: WiFi PCIe autosuspend 3s->5s"
ui_print "  P16: ORMS re-check in Slow daemon every 50min"
ui_print "  Kept from v5.0: all CPU/GPU/memory/bus/network"
ui_print "  tuning, PCIe ASPM+L1.2, cpufreq_bouncing off,"
ui_print "  alloc_adjust_ctrl=0, screen-off idle detector"
ui_print ""

mkdir -p "/data/adb/batteryboost_backup" 2>/dev/null

chmod 0755 "$MODPATH/service.sh"
chmod 0755 "$MODPATH/post-fs-data.sh"
chmod 0755 "$MODPATH/orms_stub" 2>/dev/null
[ -f "$MODPATH/uninstall.sh" ] && chmod 0755 "$MODPATH/uninstall.sh"
for s in utils cpu gpu bus memory io network display oplus orms irq modem; do
    chmod 0755 "$MODPATH/scripts/${s}.sh" 2>/dev/null
done

ui_print "======================================"
ui_print "  Done. Reboot device."
ui_print "  Log: /data/local/tmp/batteryboost.log"
ui_print "======================================"
ui_print ""
exit 0
