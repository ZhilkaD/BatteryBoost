#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

OD="/sys/kernel/oplus_display"
[ -d "$OD" ] || { log "SKIP display (no oplus_display)"; return 0; }

_owr() {
    local f="$OD/$1" v="$2" n="$3"
    [ -f "$f" ] || { log "SKIP $n"; SKIPPED=$((SKIPPED+1)); return; }
    local old; old="$(cat "$f" 2>/dev/null | head -1)"
    echo "$v" > "$f" 2>/dev/null
    local got; got="$(cat "$f" 2>/dev/null | head -1)"
    log " OK  $n: [$old]->[$got]"; APPLIED=$((APPLIED+1))
}

sec "OPLUS DISPLAY"
_owr "backlight_smooth"          "1" "backlight_smooth"
_owr "aod_light_mode_set"        "0" "aod_light_mode"
_owr "ultra_low_power_aod_mode"  "1" "ultra_low_power_aod (0->1)"
_owr "hbm"                       "0" "hbm off"
_owr "dimlayer_hbm"              "0" "dimlayer_hbm off"

sec "QSYNC"
setprop vendor.display.enable_qsync_idle 1 2>/dev/null
setprop persist.oplus.display.vrr 1 2>/dev/null
setprop persist.sys.oplus.perfetto.enable false 2>/dev/null

log "Display v3.0 done"
