#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

sec "ORMS NEUTRALIZATION"

setprop vendor.oplus.orms.enable false 2>/dev/null && log " OK  orms.enable=false"
setprop persist.vendor.oplus.orms.enable false 2>/dev/null && log " OK  persist.orms.enable=false"
setprop persist.sys.orms.name "" 2>/dev/null

ORMS_PID="$(getprop init.svc_debug_pid.vendor.oplus.ormsHalService-aidl-default 2>/dev/null)"
if [ -n "$ORMS_PID" ] && [ "$ORMS_PID" -gt 0 ] 2>/dev/null; then
    ORMS_CMD="$(cat /proc/$ORMS_PID/cmdline 2>/dev/null | tr '\0' ' ')"
    ORMS_EXE="$(readlink /proc/$ORMS_PID/exe 2>/dev/null)"
    case "$ORMS_CMD" in
        *sleep*|*stub*|*infinity*)
            log " OK  ORMS stub running (PID=$ORMS_PID) — neutralized"
            ;;
        *)
            stop vendor.oplus.ormsHalService-aidl-default 2>/dev/null
            log "WARN ORMS real binary PID=$ORMS_PID exe=$ORMS_EXE — stopped service"
            ;;
    esac
else
    log " OK  ORMS not running"
fi

if [ -f "/proc/oplus_frame_boost/stune_boost" ] && [ -n "$STUNE_VAL" ]; then
    echo "$STUNE_VAL" > /proc/oplus_frame_boost/stune_boost 2>/dev/null
    got4="$(cat /proc/oplus_frame_boost/stune_boost 2>/dev/null | awk '{print $4}')"
    [ "$got4" = "160" ] && log " OK  stune_boost [3]=160" || log "WARN stune_boost [3]=$got4"
fi

if [ -f "/proc/oplus_mem/alloc_adjust_ctrl" ]; then
    old="$(cat /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null)"
    echo "0" > /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null
    got="$(cat /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null)"
    [ "$got" = "0" ] && log " OK  alloc_adjust_ctrl [$old]->[0]" \
                     || log "WARN alloc_adjust_ctrl got=$got"
fi

log "ORMS v3.0 done"
