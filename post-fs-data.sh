#!/system/bin/sh
set +e
[ -z "$MODDIR" ] && MODDIR="${0%/*}"
export MODDIR

mkdir -p /data/local/tmp 2>/dev/null

. "$MODDIR/scripts/utils.sh" || exit 0
init_log "new"
log "[EARLY] post-fs-data v3.0 PID=$$"

VM="/proc/sys/vm"
KS="/proc/sys/kernel"

write_val "$KS/sched_util_clamp_min" "128" "[E] clamp_min"
write_val "$KS/sched_pelt_multiplier"  "4" "[E] pelt_mult"
write_val "$KS/sched_schedstats"       "0" "[E] schedstats"
write_val "$KS/perf_cpu_time_max_percent" "5" "[E] perf_cpu_time"
write_val "$KS/sched_nr_migrate"      "24" "[E] nr_migrate"
write_val "$KS/sched_wakeup_granularity_ns" "3000000" "[E] wakeup_gran"
write_val "$KS/sched_migration_cost_ns"     "1000000" "[E] migr_cost"
write_val "$KS/sched_tunable_scaling"             "1" "[E] tunable_scaling (0->1 log)"

write_val "$VM/swappiness"             "60" "[E] swappiness"
write_val "$VM/vfs_cache_pressure"     "80" "[E] vfs_pressure"
write_val "$VM/dirty_background_ratio"  "8" "[E] dirty_bg"
write_val "$VM/dirty_ratio"            "25" "[E] dirty_ratio"
write_val "$VM/dirty_expire_centisecs" "4000" "[E] dirty_expire"
write_val "$VM/dirty_writeback_centisecs" "1500" "[E] dirty_wb"
write_val "$VM/min_free_kbytes"      "16384" "[E] min_free"
write_val "$VM/extra_free_kbytes"    "24576" "[E] extra_free"
write_val "$VM/watermark_scale_factor"  "20" "[E] watermark"
write_val "$VM/laptop_mode"             "1" "[E] laptop_mode"
write_val "$VM/stat_interval"           "2" "[E] stat_interval"

write_val "/proc/sys/net/ipv4/tcp_slow_start_after_idle" "0" "[E] tcp_slow_start"
write_val "/proc/sys/net/ipv4/tcp_fastopen"              "3" "[E] tcp_fastopen"

write_val "/sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres"    "92" "[E] Prime busy_up"
write_val "/sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres"  "10" "[E] Prime busy_down"
write_val "/sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms" "50" "[E] Prime offline_delay"
write_val "/sys/devices/system/cpu/cpu4/core_ctl/min_cpus"          "1" "[E] Gold min_cpus"

write_val "/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq" "441600" "[E] Silver min_freq"
write_val "/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq" "1804800" "[E] Silver max_freq"
write_val "/sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq" "2112000" "[E] Gold max_freq cap"
write_val "/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq" "2707200" "[E] Prime max_freq (daemon holds)"

write_val "/sys/devices/system/cpu/cpu0/core_ctl/enable" "1" "[E] Silver core_ctl enable"
write_val "/sys/devices/system/cpu/cpu0/core_ctl/min_cpus" "1" "[E] Silver min_cpus"
write_val "/sys/devices/system/cpu/cpu0/core_ctl/max_cpus" "4" "[E] Silver max_cpus"
write_val "/sys/devices/system/cpu/cpu0/core_ctl/task_thres" "4" "[E] Silver task_thres"
write_val "/sys/devices/system/cpu/cpu0/core_ctl/need_cpus" "1" "[E] Silver need_cpus (4->1 min_cpus floor)"
write_val "/sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms" "50" "[E] Silver offline_delay (200->50)"
write_val "/sys/devices/system/cpu/cpu4/core_ctl/need_cpus" "1" "[E] Gold need_cpus (3->1)"

ORMS_BIN="/odm/bin/hw/vendor.oplus.hardware.ormsHalService-aidl-service"
if [ -x "$ORMS_BIN" ] && [ -f "$MODDIR/orms_stub" ]; then
    mount --bind "$MODDIR/orms_stub" "$ORMS_BIN" 2>/dev/null && log " OK  [E] ORMS stub bind-mounted over binary"
fi

OMRG="/sys/devices/platform/soc/soc:oplus-omrg/oplus-omrg0/ruler_enable"
if [ -f "$OMRG" ]; then
    echo "disabled" > "$OMRG" 2>/dev/null
    got="$(cat "$OMRG" 2>/dev/null)"
    [ "$got" = "disabled" ] && log " OK  [E] oplus-omrg ruler disabled" || log "WARN [E] oplus-omrg ruler got=$got"
fi

if [ -f "/proc/oplus_mem/alloc_adjust_ctrl" ]; then
    echo "0" > /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null
    log " OK  [E] alloc_adjust_ctrl=0 (early, stop oplus_mem override)"
fi

summary
log "[EARLY] post-fs-data done: ok=$APPLIED skip=$SKIPPED fail=$FAILED"
exit 0
