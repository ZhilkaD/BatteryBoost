#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

GPU="/sys/class/kgsl/kgsl-3d0"
[ -d "$GPU" ] || { log "SKIP gpu (no kgsl-3d0)"; return 0; }

sec "GPU (Adreno725)"
write_retry "$GPU/force_no_nap"    "0" "force_no_nap (1->0 NAP on)"
write_val   "$GPU/idle_timer"     "64" "idle_timer (80->64ms)"
write_val   "$GPU/default_pwrlevel" "6" "pwrlevel (5->6 = 220MHz)"
write_val   "$GPU/wake_timeout"   "60" "wake_timeout (100->60ms)"
write_val   "$GPU/minbw_timer"    "20" "minbw_timer (10->20ms)"
write_val   "$GPU/force_bus_on"    "0" "force_bus_on off"
write_val   "$GPU/force_clk_on"    "0" "force_clk_on off"
write_val   "$GPU/force_rail_on"   "0" "force_rail_on off"
write_val   "$GPU/bus_split"       "1" "bus_split"
write_val   "$GPU/ifpc"            "1" "ifpc"
write_val   "$GPU/acd"             "1" "acd"
write_val   "$GPU/hwcg"            "1" "hwcg"
write_val   "$GPU/pwrscale"        "1" "pwrscale"

log "GPU v3.0 done"
