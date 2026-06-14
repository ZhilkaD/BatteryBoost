#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

STUNE="/proc/oplus_frame_boost/stune_boost"
STUNE_VAL="0 0 90 160 450 350 0 0 0 0 30 30 60 450 80 680 180"

sec "OPLUS FRAME BOOST"
if [ -f "$STUNE" ]; then
    sleep 2
    echo "$STUNE_VAL" > "$STUNE" 2>/dev/null
    got4="$(cat "$STUNE" 2>/dev/null | awk '{print $4}')"
    [ "$got4" = "160" ] && { log " OK  stune_boost [3]=160"; APPLIED=$((APPLIED+1)); } \
                        || { log "WARN stune_boost [3]=$got4 (ORMS may reset)"; SKIPPED=$((SKIPPED+1)); }
else
    log "SKIP stune_boost (not found)"; SKIPPED=$((SKIPPED+1))
fi

sec "OPLUS-OMRG RULER DISABLE"
OMRG="/sys/devices/platform/soc/soc:oplus-omrg/oplus-omrg0"
if [ -f "$OMRG/ruler_enable" ]; then
    old="$(cat "$OMRG/ruler_enable" 2>/dev/null)"
    echo "disabled" > "$OMRG/ruler_enable" 2>/dev/null
    got="$(cat "$OMRG/ruler_enable" 2>/dev/null)"
    [ "$got" = "disabled" ] && { log " OK  oplus-omrg ruler_enable [$old]->[disabled] (kernel ruler off)"; APPLIED=$((APPLIED+1)); } \
                      || { log "WARN oplus-omrg ruler_enable got=$got"; SKIPPED=$((SKIPPED+1)); }
else
    log "SKIP oplus-omrg ruler_enable (not found)"; SKIPPED=$((SKIPPED+1))
fi

sec "OPLUS MISC"
setprop sys.opluspm.enable true 2>/dev/null && log " OK  opluspm"
setprop sys.oplus.vm.oplus_compact_memory 1 2>/dev/null && log " OK  compact_memory"
setprop persist.sys.oplus.perfetto.enable false 2>/dev/null
setprop vendor.perf.iop_v3.enable false 2>/dev/null
setprop persist.vendor.qperfget false 2>/dev/null

sec "OPLUS TRACING OFF"
setprop debug.oplus.systrace_enhance false 2>/dev/null
resetprop debug.oplus.systrace_enhance false 2>/dev/null
log " OK  systrace_enhance=false (setprop+resetprop)"
setprop debug.sf.oplus_display_trace.enable 0 2>/dev/null
setprop debug.hwui.skia_atrace_enabled false 2>/dev/null
setprop debug.hwui.skia_tracing_enabled false 2>/dev/null

sec "OPLUSSTORAGE ALARM SUPPRESS"
setprop persist.sys.oplus.storage.bandwidth_monitor 0 2>/dev/null && log " OK  storage_bw_monitor=0"
settings put global oplus_storage_bandwidth_monitor 0 2>/dev/null

sec "PERFSERVICE MITIGATE"
setprop vendor.perf.hmp.num_threads 4 2>/dev/null && log " OK  perf hmp_num_threads=4"
setprop vendor.perf.debug.level 0 2>/dev/null && log " OK  perf debug_level=0"
setprop vendor.perf.topapp.boost.enable 0 2>/dev/null && log " OK  perf topapp_boost=0"
setprop vendor.hypervisor.throttle.enable 0 2>/dev/null

log "Oplus v3.0 done"
