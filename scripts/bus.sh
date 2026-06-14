#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

DDR_BW="/sys/devices/system/cpu/bus_dcvs/DDR/19091000.qcom,bwmon-ddr"
LLCC_BW="/sys/devices/system/cpu/bus_dcvs/LLCC/190b6400.qcom,bwmon-llcc"

sec "DDR BUS DCVS"
write_val "$DDR_BW/io_percent"  "90" "DDR io_percent (80->90)"
write_val "$DDR_BW/decay_rate"  "95" "DDR decay_rate (90->95)"
write_val "$DDR_BW/window_ms"   "50" "DDR window_ms (40->50)"
write_val "$DDR_BW/up_scale"   "300" "DDR up_scale (250->300)"
write_val "$DDR_BW/down_thres"  "40" "DDR down_thres (30->40)"
write_val "$DDR_BW/down_count"   "8" "DDR down_count (3->8 faster DDR down)"
write_val "$DDR_BW/up_thres"    "15" "DDR up_thres (10->15)"
log "SKIP DDR sample_ms (firmware-locked, resets in 3-4s)"

sec "DDR SILVER FREQ MAP"
DDR_SILVER="/sys/devices/system/cpu/bus_dcvs/DDR/soc:qcom,memlat:ddr:silver"
if [ -d "$DDR_SILVER" ]; then
    write_val "$DDR_SILVER/freq_scale_pct"  "15" "DDR silver freq_scale_pct (0->15 gentle limit)"
else
    log "SKIP DDR silver freq_map (no dir)"
fi

sec "LLCC BUS DCVS"
write_val "$LLCC_BW/io_percent" "90" "LLCC io_percent (80->90)"
write_val "$LLCC_BW/decay_rate" "95" "LLCC decay_rate (90->95)"
write_val "$LLCC_BW/window_ms"  "50" "LLCC window_ms (40->50)"
write_val "$LLCC_BW/up_scale"  "300" "LLCC up_scale (250->300)"
log "SKIP LLCC sample_ms (firmware-locked, resets in 3-4s)"

sec "L3 CACHE SPM"
for cl in gold prime silver; do
    L3N="/sys/devices/system/cpu/bus_dcvs/L3/soc:qcom,memlat:l3:${cl}"
    [ -f "$L3N/spm_window_size" ] && write_val "$L3N/spm_window_size" "15" "L3 $cl spm_window (10->15)"
done
L3PC="/sys/devices/system/cpu/bus_dcvs/L3/soc:qcom,memlat:l3:prime-compute"
[ -f "$L3PC/spm_window_size" ] && write_val "$L3PC/spm_window_size" "15" "L3 prime-compute spm_window"

sec "L3 SILVER FREQ CAP"
L3_SILVER="/sys/devices/system/cpu/bus_dcvs/L3/soc:qcom,memlat:l3:silver"
if [ -d "$L3_SILVER" ]; then
    write_val "$L3_SILVER/ipm_ceil"      "1000" "L3 silver ipm_ceil (400->1000 gentle limit)"
else
    log "SKIP L3 silver freq cap"
fi

log "Bus v3.0 done"
