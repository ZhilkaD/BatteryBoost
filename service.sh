#!/system/bin/sh
set +e
[ -z "$MODDIR" ] && MODDIR="${0%/*}"
export MODDIR

BOOT_WAIT=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    [ "$BOOT_WAIT" -ge 300 ] && exit 0
    sleep 1; BOOT_WAIT=$((BOOT_WAIT+1))
done
sleep 20

. "$MODDIR/scripts/utils.sh" || exit 0
init_log "append"
check_device
log "service.sh v3.0 PID=$$ waited=${BOOT_WAIT}s+20s"

ORMS_PID="$(getprop init.svc_debug_pid.vendor.oplus.ormsHalService-aidl-default 2>/dev/null)"
if [ -n "$ORMS_PID" ] && [ "$ORMS_PID" -gt 0 ] 2>/dev/null; then
    ORMS_CMD="$(cat /proc/$ORMS_PID/cmdline 2>/dev/null | tr '\0' ' ')"
    ORMS_EXE="$(readlink /proc/$ORMS_PID/exe 2>/dev/null)"
    case "$ORMS_CMD" in
        *sleep*|*stub*|*infinity*) log " OK  ORMS neutralized (stub PID=$ORMS_PID)" ;;
        *) stop vendor.oplus.ormsHalService-aidl-default 2>/dev/null
           log "WARN ORMS real binary PID=$ORMS_PID exe=$ORMS_EXE, stopped service" ;;
    esac
    log "INFO ORMS cmd=$ORMS_CMD"
else
    log " OK  ORMS not running"
fi

STUNE_VAL="0 0 90 160 450 350 0 0 0 0 30 30 60 450 80 680 180"
export STUNE_VAL

_src() {
    local p="$MODDIR/scripts/${1}.sh"
    [ -f "$p" ] && { log "--- loading $1 ---"; . "$p"; } || log "SKIP $1 (not found)"
}

_src cpu
_src gpu
_src memory
_src io
_src network
_src bus
_src display
_src oplus
_src orms
_src irq
_src modem

summary

RLOG="/data/local/tmp/batteryboost.log"
rl() { echo "[$(date '+%H:%M:%S')] [$1] $2" >> "$RLOG" 2>/dev/null; }
rw() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }
_nc() { local cur; cur="$(cat "$1" 2>/dev/null | tr -d '[:space:]')"; local wv; wv="$(echo "$2" | tr -d '[:space:]')"; [ "$cur" != "$wv" ] && { rw "$1" "$2"; return 0; }; return 1; }

(
    rl "FAST" "Fast daemon v3.0 started (30s, 10 params)"
    total=0

    CLAMP="/proc/sys/kernel/sched_util_clamp_min"
    NAP="/sys/class/kgsl/kgsl-3d0/force_no_nap"
    GOLD_MIN="/sys/devices/system/cpu/cpu4/core_ctl/min_cpus"
    PRIME_UP="/sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres"
    PRIME_DN="/sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres"
    LLCC_PCT="/sys/devices/system/cpu/bus_dcvs/LLCC/190b6400.qcom,bwmon-llcc/io_percent"
    STUNE="/proc/oplus_frame_boost/stune_boost"
    PRIME_MAX="/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq"
    SILVER_MAX="/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq"
    SBOOST="/proc/sys/walt/sched_boost"

    while true; do
        sleep 30
        fixes=0

        cur="$(cat "$CLAMP" 2>/dev/null)"
        if [ -n "$cur" ] && [ "$cur" -gt 256 ] 2>/dev/null; then
            rw "$CLAMP" "128"; fixes=$((fixes+1)); rl "FAST" "clamp_min $cur -> 128"
        fi

        cur="$(cat "$NAP" 2>/dev/null)"
        [ "$cur" != "0" ] && { rw "$NAP" "0"; fixes=$((fixes+1)); rl "FAST" "gpu_nap $cur -> 0"; }

        cur="$(cat "$GOLD_MIN" 2>/dev/null)"
        [ "$cur" != "1" ] && { rw "$GOLD_MIN" "1"; fixes=$((fixes+1)); rl "FAST" "Gold min_cpus $cur -> 1"; }

        cur="$(cat "$PRIME_UP" 2>/dev/null | tr -d '[:space:]')"
        [ "$cur" != "92" ] && { rw "$PRIME_UP" "92"; fixes=$((fixes+1)); rl "FAST" "Prime busy_up $cur -> 92"; }

        cur="$(cat "$PRIME_DN" 2>/dev/null | tr -d '[:space:]')"
        [ "$cur" != "10" ] && { rw "$PRIME_DN" "10"; fixes=$((fixes+1)); rl "FAST" "Prime busy_dn $cur -> 10"; }

        cur="$(cat "$LLCC_PCT" 2>/dev/null)"
        [ "$cur" != "90" ] && { rw "$LLCC_PCT" "90"; fixes=$((fixes+1)); rl "FAST" "LLCC io_pct $cur -> 90"; }

        if [ -f "$STUNE" ]; then
            cur="$(cat "$STUNE" 2>/dev/null | awk '{print $4}')"
            [ "$cur" != "160" ] && { echo "$STUNE_VAL" > "$STUNE" 2>/dev/null; fixes=$((fixes+1)); rl "FAST" "stune[3] $cur -> 160"; }
        fi

        cur="$(cat "$PRIME_MAX" 2>/dev/null)"
        if [ -n "$cur" ] && [ "$cur" -lt 2707200 ] 2>/dev/null; then
            rw "$PRIME_MAX" "2707200"; fixes=$((fixes+1)); rl "FAST" "Prime max $cur -> 2707200"
        fi

        cur="$(cat "$SILVER_MAX" 2>/dev/null)"
        if [ -n "$cur" ] && [ "$cur" -lt 1804800 ] 2>/dev/null; then
            rw "$SILVER_MAX" "1804800"; fixes=$((fixes+1)); rl "FAST" "Silver max $cur -> 1804800"
        fi

        if [ -f "$SBOOST" ]; then
            cur="$(cat "$SBOOST" 2>/dev/null | tr -d '[:space:]')"
            [ -n "$cur" ] && [ "$cur" != "0" ] && { rw "$SBOOST" "0"; fixes=$((fixes+1)); rl "FAST" "sched_boost $cur -> 0"; }
        fi

        if [ "$fixes" -gt 0 ]; then
            total=$((total+fixes))
            rl "FAST" "Cycle: $fixes fixes (total=$total)"
        fi
    done
) &
log "Fast daemon PID=$!"

(
    rl "MED" "Medium daemon v3.0 started (60s, 21 params)"
    total=0

    SILVER_TL="/sys/devices/system/cpu/cpufreq/policy0/walt/target_loads"
    SILVER_HS="/sys/devices/system/cpu/cpufreq/policy0/walt/hispeed_freq"
    SILVER_HL="/sys/devices/system/cpu/cpufreq/policy0/walt/hispeed_load"
    SILVER_MINF="/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq"
    GOLD_TL="/sys/devices/system/cpu/cpufreq/policy4/walt/target_loads"
    GPU_PWR="/sys/class/kgsl/kgsl-3d0/default_pwrlevel"
    GPU_IDLE="/sys/class/kgsl/kgsl-3d0/idle_timer"
    DDR_IO="/sys/devices/system/cpu/bus_dcvs/DDR/19091000.qcom,bwmon-ddr/io_percent"
    BUSY_HYST_CPUS="/proc/sys/walt/sched_busy_hysteresis_enable_cpus"
    BUSY_HYST_NS="/proc/sys/walt/sched_busy_hyst_ns"
    DYN_SWAP="/proc/oplus_mem/dynamic_swappiness"
    SILVER_CC="/sys/devices/system/cpu/cpu0/core_ctl/enable"
    SWAPPINESS="/proc/sys/vm/swappiness"
    ALLOC_CTRL="/proc/oplus_mem/alloc_adjust_ctrl"
    BOUNCE_EN="/sys/module/cpufreq_bouncing/parameters/enable"
    SILVER_NC="/sys/devices/system/cpu/cpu0/core_ctl/need_cpus"
    GOLD_NC="/sys/devices/system/cpu/cpu4/core_ctl/need_cpus"
    TSCALE="/proc/sys/kernel/sched_tunable_scaling"
    SILVER_OD="/sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms"
    INIT_TL="/proc/sys/walt/sched_init_task_load"
    OMRG="/sys/devices/platform/soc/soc:oplus-omrg/oplus-omrg0/ruler_enable"

    while true; do
        sleep 60
        fixes=0

        _nc "$SILVER_TL" "85" 2>/dev/null && { fixes=$((fixes+1)); rl "MED" "Silver target_loads -> 85"; }
        _nc "$SILVER_HS" "940800" 2>/dev/null && { fixes=$((fixes+1)); rl "MED" "Silver hispeed -> 940800"; }
        _nc "$SILVER_HL" "87" 2>/dev/null && { fixes=$((fixes+1)); rl "MED" "Silver hispeed_load -> 87"; }

        cur="$(cat "$SILVER_MINF" 2>/dev/null)"
        if [ -n "$cur" ] && [ "$cur" -gt 441600 ] 2>/dev/null; then
            rw "$SILVER_MINF" "441600"; fixes=$((fixes+1)); rl "MED" "Silver min_freq $cur -> 441600"
        fi

        cur="$(cat "$GOLD_TL" 2>/dev/null | tr -d '[:space:]')"
        gold_tl_ns="852112000:97"
        [ "$cur" != "$gold_tl_ns" ] && { rw "$GOLD_TL" "85 2112000:97"; fixes=$((fixes+1)); rl "MED" "Gold target_loads -> 85 2112000:97"; }

        cur="$(cat "$GPU_PWR" 2>/dev/null)"
        [ "$cur" != "6" ] && { rw "$GPU_PWR" "6"; fixes=$((fixes+1)); rl "MED" "GPU pwrlevel $cur -> 6"; }

        _nc "$GPU_IDLE" "64" 2>/dev/null && { fixes=$((fixes+1)); rl "MED" "GPU idle_timer -> 64"; }

        cur="$(cat "$DDR_IO" 2>/dev/null)"
        [ "$cur" != "90" ] && { rw "$DDR_IO" "90"; fixes=$((fixes+1)); rl "MED" "DDR io_pct $cur -> 90"; }

        cur="$(cat "$BUSY_HYST_CPUS" 2>/dev/null)"
        [ "$cur" != "255" ] && { rw "$BUSY_HYST_CPUS" "255"; fixes=$((fixes+1)); rl "MED" "busy_hyst_cpus $cur -> 255"; }

        _nc "$BUSY_HYST_NS" "2000000" 2>/dev/null && { fixes=$((fixes+1)); rl "MED" "busy_hyst_ns -> 2000000"; }

        if [ -f "$DYN_SWAP" ]; then
            cur="$(cat "$DYN_SWAP" 2>/dev/null | awk '{print $1}')"
            [ "$cur" != "60" ] && { echo "60 4096 80 2048" > "$DYN_SWAP" 2>/dev/null; fixes=$((fixes+1)); rl "MED" "dynamic_swappiness $cur -> 60 4096 80 2048"; }
        fi

        _nc "$SILVER_CC" "1" 2>/dev/null && { fixes=$((fixes+1)); rl "MED" "Silver core_ctl -> 1"; }

        cur="$(cat "$SWAPPINESS" 2>/dev/null)"
        [ "$cur" != "60" ] && { rw "$SWAPPINESS" "60"; fixes=$((fixes+1)); rl "MED" "swappiness $cur -> 60"; }

        if [ -f "$ALLOC_CTRL" ]; then
            cur="$(cat "$ALLOC_CTRL" 2>/dev/null)"
            [ "$cur" != "0" ] && { rw "$ALLOC_CTRL" "0"; fixes=$((fixes+1)); rl "MED" "alloc_adjust_ctrl $cur -> 0"; }
        fi

        if [ -f "$BOUNCE_EN" ]; then
            cur="$(cat "$BOUNCE_EN" 2>/dev/null)"
            [ "$cur" != "0" ] && { rw "$BOUNCE_EN" "0"; fixes=$((fixes+1)); rl "MED" "cpufreq_bouncing $cur -> 0"; }
        fi

        if [ -f "$SILVER_NC" ]; then
            cur="$(cat "$SILVER_NC" 2>/dev/null)"
            [ "$cur" != "1" ] && { rw "$SILVER_NC" "1"; fixes=$((fixes+1)); rl "MED" "Silver need_cpus $cur -> 1"; }
        fi

        if [ -f "$GOLD_NC" ]; then
            cur="$(cat "$GOLD_NC" 2>/dev/null)"
            [ "$cur" != "1" ] && { rw "$GOLD_NC" "1"; fixes=$((fixes+1)); rl "MED" "Gold need_cpus $cur -> 1"; }
        fi

        if [ -f "$TSCALE" ]; then
            cur="$(cat "$TSCALE" 2>/dev/null)"
            [ "$cur" != "1" ] && { rw "$TSCALE" "1"; fixes=$((fixes+1)); rl "MED" "tunable_scaling $cur -> 1"; }
        fi

        if [ -f "$SILVER_OD" ]; then
            cur="$(cat "$SILVER_OD" 2>/dev/null)"
            [ "$cur" != "50" ] && { rw "$SILVER_OD" "50"; fixes=$((fixes+1)); rl "MED" "Silver offline_delay $cur -> 50"; }
        fi

        if [ -f "$INIT_TL" ]; then
            cur="$(cat "$INIT_TL" 2>/dev/null | tr -d '[:space:]')"
            [ "$cur" != "00" ] && { printf '0\t0' > "$INIT_TL" 2>/dev/null; fixes=$((fixes+1)); rl "MED" "init_task_load -> 0TAB0"; }
        fi

        if [ -f "$OMRG" ]; then
            cur="$(cat "$OMRG" 2>/dev/null)"
            [ "$cur" != "disabled" ] && { rw "$OMRG" "disabled"; fixes=$((fixes+1)); rl "MED" "omrg ruler $cur -> disabled"; }
        fi

        if [ "$fixes" -gt 0 ]; then
            total=$((total+fixes))
            rl "MED" "Cycle: $fixes fixes (total=$total)"
        fi
    done
) &
log "Medium daemon PID=$!"

(
    rl() { echo "[$(date '+%H:%M:%S')] [IRQ] $1" >> "$RLOG" 2>/dev/null; }

    _wifi() {
        local cnt=0
        for pat in pci0_wlan_ce_0 pci0_wlan_ce_1 pci0_wlan_ce_2 pci0_wlan_ce_3 pci0_wlan_grp_dp_0 pci0_wlan_grp_dp_1 wlan_wake_irq; do
            local n af cur
            n="$(grep "$pat" /proc/interrupts 2>/dev/null | awk '{gsub(/:/, "", $1); print $1}' | head -1)"
            [ -z "$n" ] && continue
            af="/proc/irq/${n}/smp_affinity"
            [ -w "$af" ] || continue
            cur="$(cat "$af" 2>/dev/null | tr -d ' \n')"
            [ "$cur" = "0f" ] || [ "$cur" = "0000000f" ] && continue
            echo "0f" > "$af" 2>/dev/null && cnt=$((cnt+1))
        done
        [ "$cnt" -gt 0 ] && rl "$cnt WiFi IRQ -> Silver"
    }

    sleep 210; _wifi
    while true; do sleep 1200; _wifi; done
) &

(
    LLCC_BW="/sys/devices/system/cpu/bus_dcvs/LLCC/190b6400.qcom,bwmon-llcc"
    WP="/proc/sys/walt"
    rl() { echo "[$(date '+%H:%M:%S')] [SLOW] $1" >> "$RLOG" 2>/dev/null; }
    rw() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }
    iter=0

    rl "Slow daemon v3.0 started (300s)"

    while true; do
        sleep 300
        iter=$((iter+1))
        fixed=""

        _c() {
            local f="$1" w="$2" n="$3"
            local cur; cur="$(cat "$f" 2>/dev/null)"
            [ "$cur" != "$w" ] && { rw "$f" "$w"; fixed="$fixed $n"; }
        }

        cur="$(cat /proc/sys/kernel/sched_util_clamp_min 2>/dev/null)"
        [ -n "$cur" ] && [ "$cur" -gt 256 ] 2>/dev/null && {
            rw /proc/sys/kernel/sched_util_clamp_min "128"; fixed="$fixed clamp_min"
        }

        _c "$WP/sched_lib_mask_force"                    "112"  "lib_mask"
        _c "/sys/class/kgsl/kgsl-3d0/force_no_nap"       "0"    "gpu_nap"
        _c "/proc/sys/kernel/sched_schedstats"            "0"    "schedstats"
        _c "$WP/sched_coloc_busy_hysteresis_enable_cpus"  "255"  "coloc_hyst_cpus"
        _c "/proc/sys/vm/swappiness"                     "60"   "swappiness"
        _c "$WP/sched_conservative_pl"                   "1"    "conservative_pl"
        _c "$LLCC_BW/decay_rate"                         "95"   "llcc_decay"
        _c "$LLCC_BW/up_scale"                          "300"   "llcc_up_scale"
        _c "$LLCC_BW/window_ms"                         "50"   "llcc_window"
        _c "$WP/sched_hyst_min_coloc_ns"          "80000000"   "hyst_min_coloc"
        _c "$WP/sched_coloc_busy_hyst_max_ms"            "5000" "coloc_hyst_max"
        cur="$(cat "$WP/sched_upmigrate" 2>/dev/null | tr -d '[:space:]')"
        [ "$cur" != "9595" ] && { printf '95\t95' > "$WP/sched_upmigrate" 2>/dev/null; fixed="$fixed upmigrate"; }
        _c "/sys/class/kgsl/kgsl-3d0/wake_timeout"       "60"   "gpu_wake_tmo"
        _c "/sys/class/kgsl/kgsl-3d0/minbw_timer"        "20"   "gpu_minbw"
        _c "$WP/sched_enable_tp"                           "0"  "enable_tp"

        OMRG_R="/sys/devices/platform/soc/soc:oplus-omrg/oplus-omrg0/ruler_enable"
        if [ -f "$OMRG_R" ]; then
            cur="$(cat "$OMRG_R" 2>/dev/null)"
            [ "$cur" != "disabled" ] && { rw "$OMRG_R" "disabled"; fixed="$fixed omrg_ruler"; }
        fi

        ASPM="/sys/module/pcie_aspm/parameters/policy"
        if [ -f "$ASPM" ]; then
            cur="$(cat "$ASPM" 2>/dev/null | head -1)"
            case "$cur" in
                *powersave*|*Powersave*) ;;
                *) echo "powersave" > "$ASPM" 2>/dev/null; fixed="$fixed aspm_powersave" ;;
            esac
        fi

        L1ASPM="/sys/bus/pci/devices/0000:01:00.0/link/l1_aspm"
        if [ -f "$L1ASPM" ]; then
            cur="$(cat "$L1ASPM" 2>/dev/null)"
            [ "$cur" != "1" ] && { rw "$L1ASPM" "1"; fixed="$fixed wifi_l1_aspm"; }
        fi

        AUTOSUSPEND="/sys/bus/pci/devices/0000:01:00.0/power/autosuspend_delay_ms"
        if [ -f "$AUTOSUSPEND" ]; then
            cur="$(cat "$AUTOSUSPEND" 2>/dev/null)"
            [ "$cur" != "5000" ] && { rw "$AUTOSUSPEND" "5000"; fixed="$fixed pcie_autosuspend"; }
        fi

        EFFIENCY="/sys/module/cpufreq_effiency/parameters/cluster0_effiency"
        if [ -f "$EFFIENCY" ]; then
            cur="$(cat "$EFFIENCY" 2>/dev/null | tr -d '[:space:]')"
            want="307200,45000,0,0,0"
            [ "$cur" != "$want" ] && { rw "$EFFIENCY" "307200,45000,0,0,0"; fixed="$fixed silver_effiency"; }
        fi

        if [ $((iter % 10)) -eq 0 ]; then
            ORMS_PID="$(getprop init.svc_debug_pid.vendor.oplus.ormsHalService-aidl-default 2>/dev/null)"
            if [ -n "$ORMS_PID" ] && [ "$ORMS_PID" -gt 0 ] 2>/dev/null; then
                ORMS_CMD="$(cat /proc/$ORMS_PID/cmdline 2>/dev/null | tr '\0' ' ')"
                case "$ORMS_CMD" in
                    *sleep*|*stub*|*infinity*) ;;
                    *) stop vendor.oplus.ormsHalService-aidl-default 2>/dev/null
                       fixed="$fixed orms_restop" ;;
                esac
            fi
        fi

        [ -n "$fixed" ] && rl "[$iter] Fixed:$fixed"

        if [ $((iter % 6)) -eq 0 ]; then
            ua="$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)"
            p0f="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null)"
            p0m="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 2>/dev/null)"
            p4f="$(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq 2>/dev/null)"
            p7a="$(cat /sys/devices/system/cpu/cpu7/core_ctl/active_cpus 2>/dev/null)"
            p7m="$(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq 2>/dev/null)"
            g4m="$(cat /sys/devices/system/cpu/cpu4/core_ctl/min_cpus 2>/dev/null)"
            clamp="$(cat /proc/sys/kernel/sched_util_clamp_min 2>/dev/null)"
            nap="$(cat /sys/class/kgsl/kgsl-3d0/force_no_nap 2>/dev/null)"
            s0e="$(cat /sys/devices/system/cpu/cpu0/core_ctl/enable 2>/dev/null)"
            aspm="$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null | head -1)"
            bounce="$(cat /sys/module/cpufreq_bouncing/parameters/enable 2>/dev/null)"
            s0nc="$(cat /sys/devices/system/cpu/cpu0/core_ctl/need_cpus 2>/dev/null)"
            sboost="$(cat /proc/sys/kernel/sched_boost 2>/dev/null)"
            rl "[$iter] ${ua}uA Silver=${p0f}(max=${p0m}) Gold=${p4f} Prime_act=${p7a} Prime_max=${p7m} min=${g4m} clamp=${clamp} nap=${nap} cc=${s0e} aspm=${aspm} bounce=${bounce} need=${s0nc} sboost=${sboost}"
        fi
    done
) &
log "Slow daemon PID=$!"

(
    PCIE="/sys/bus/pci/devices/0000:01:00.0/power/control"
    rl() { echo "[$(date '+%H:%M:%S')] [PCIE] $1" >> "$RLOG" 2>/dev/null; }
    sleep 30

    if [ -e "$PCIE" ]; then
        cur="$(cat "$PCIE" 2>/dev/null)"
        [ "$cur" != "auto" ] && {
            echo "auto" > "$PCIE" 2>/dev/null
            rl "PCIe power control -> auto"
        }
    fi

    while true; do
        sleep 600
        [ -e "$PCIE" ] && [ "$(cat "$PCIE" 2>/dev/null)" != "auto" ] && {
            echo "auto" > "$PCIE" 2>/dev/null
            rl "PCIe power control re-applied"
        }
    done
) &
log "PCIe daemon PID=$!"

(
    BL="/sys/class/backlight/panel0-backlight/brightness"
    LAST_OFF=0
    rl() { echo "[$(date '+%H:%M:%S')] [IDLE] $1" >> "$RLOG" 2>/dev/null; }
    rw() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }

    sleep 60

    while true; do
        sleep 10
        bright="$(cat "$BL" 2>/dev/null)"
        IS_OFF=0
        [ -z "$bright" ] && continue
        [ "$bright" = "0" ] && IS_OFF=1

        if [ "$IS_OFF" = "1" ] && [ "$LAST_OFF" = "0" ]; then
            rw "/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq" "300000" 2>/dev/null
            rw "/sys/class/kgsl/kgsl-3d0/idle_timer" "80" 2>/dev/null
            rl "Screen OFF: Silver min=300000 GPU idle=80"
            LAST_OFF=1
        elif [ "$IS_OFF" = "0" ] && [ "$LAST_OFF" = "1" ]; then
            rw "/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq" "441600" 2>/dev/null
            rw "/sys/class/kgsl/kgsl-3d0/idle_timer" "64" 2>/dev/null
            rl "Screen ON: Silver min=441600 GPU idle=64"
            LAST_OFF=0
        fi
    done
) &
log "Idle detector PID=$!"

(
    rl() { echo "[$(date '+%H:%M:%S')] [THERM] $1" >> "$RLOG" 2>/dev/null; }
    rw() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }

    SILVER_MAX="/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq"
    GOLD_MAX="/sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq"
    PRIME_MAX="/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq"

    S_NORM=1804800; G_NORM=2112000; P_NORM=2707200
    S_WARM=1512000; G_WARM=1766400
    S_HOT=1324800;  G_HOT=1555200;  P_HOT=2361600

    WARM=45000; HOT=50000; COOL=42000

    TZ_CPU=""
    for tz in /sys/class/thermal/thermal_zone*; do
        type="$(cat "$tz/type" 2>/dev/null)"
        case "$type" in
            *cpu-0*|*CPU*|*tsens7*|*cluster*|*compy*)
                TZ_CPU="$tz/temp"
                rl "Thermal zone: $type ($tz)"
                break
                ;;
        esac
    done
    [ -z "$TZ_CPU" ] && {
        TZ_CPU="/sys/class/thermal/thermal_zone0/temp"
        rl "Fallback thermal zone: thermal_zone0"
    }

    state="normal"
    rl "Thermal daemon v3.0 started (60s) warm=${WARM} hot=${HOT} cool=${COOL}"

    while true; do
        sleep 60
        temp="$(cat "$TZ_CPU" 2>/dev/null)"
        [ -z "$temp" ] && continue

        if [ "$temp" -gt "$HOT" ] 2>/dev/null && [ "$state" != "hot" ]; then
            rw "$SILVER_MAX" "$S_HOT"; rw "$GOLD_MAX" "$G_HOT"; rw "$PRIME_MAX" "$P_HOT"
            state="hot"
            rl "HOT ${temp}mC -> S=$S_HOT G=$G_HOT P=$P_HOT"
        elif [ "$temp" -gt "$WARM" ] 2>/dev/null && [ "$state" = "normal" ]; then
            rw "$SILVER_MAX" "$S_WARM"; rw "$GOLD_MAX" "$G_WARM"
            state="warm"
            rl "WARM ${temp}mC -> S=$S_WARM G=$G_WARM"
        elif [ "$temp" -lt "$COOL" ] 2>/dev/null && [ "$state" != "normal" ]; then
            rw "$SILVER_MAX" "$S_NORM"; rw "$GOLD_MAX" "$G_NORM"; rw "$PRIME_MAX" "$P_NORM"
            state="normal"
            rl "COOL ${temp}mC -> normal freq restored"
        fi
    done
) &
log "Thermal daemon PID=$!"

log "=== service.sh v3.0 all daemons running ==="
exit 0
