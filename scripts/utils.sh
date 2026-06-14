MODULE_NAME="BatteryBoost"
MODULE_VER="3.0.0"
LOG_FILE="/data/local/tmp/batteryboost.log"
BACKUP_DIR="/data/adb/batteryboost_backup"
BACKUP_MAP="$BACKUP_DIR/map.txt"
APPLIED=0; SKIPPED=0; FAILED=0

init_log() {
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    if [ "$1" = "new" ]; then
        {
            echo "=== $MODULE_NAME v$MODULE_VER ==="
            echo "Device: $(getprop ro.product.model) ($(getprop ro.product.device))"
            echo "Android: $(getprop ro.build.version.release) Kernel: $(uname -r)"
            echo "Boot: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "================================="
        } > "$LOG_FILE"
    else
        echo "" >> "$LOG_FILE"
        echo "=== SERVICE $(date '+%H:%M:%S') ===" >> "$LOG_FILE"
    fi
    APPLIED=0; SKIPPED=0; FAILED=0
}

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null; }
sec() { echo "" >> "$LOG_FILE"; echo "--- $1 ---" >> "$LOG_FILE"; }

_backup() {
    local f="$1" bn
    bn="$(echo "$f" | tr '/' '_')"
    [ -f "$BACKUP_DIR/$bn" ] && return
    [ -r "$f" ] || return
    cat "$f" > "$BACKUP_DIR/$bn" 2>/dev/null
    echo "$f|$bn" >> "$BACKUP_MAP" 2>/dev/null
}

write_val() {
    local f="$1" v="$2" n="${3:-$1}"
    if [ ! -e "$f" ]; then log "SKIP $n (not found)"; SKIPPED=$((SKIPPED+1)); return 1; fi
    _backup "$f"
    local old; old="$(cat "$f" 2>/dev/null | head -1)"
    echo "$v" > "$f" 2>/dev/null
    local got; got="$(cat "$f" 2>/dev/null | head -1)"
    local vs gv
    vs="$(echo "$v"   | tr -d '[:space:]')"
    gv="$(echo "$got" | tr -d '[:space:]')"
    if [ "$gv" = "$vs" ]; then
        log " OK  $n: [$old]->[$got]"; APPLIED=$((APPLIED+1)); return 0
    fi
    log "FAIL $n: want[$v] got[$got]"; FAILED=$((FAILED+1)); return 1
}

write_tab() {
    local f="$1" v1="$2" v2="$3" n="${4:-$1}"
    if [ ! -e "$f" ]; then log "SKIP $n (not found)"; SKIPPED=$((SKIPPED+1)); return 1; fi
    _backup "$f"
    local old; old="$(cat "$f" 2>/dev/null | head -1)"
    printf '%s\t%s' "$v1" "$v2" > "$f" 2>/dev/null
    local got; got="$(cat "$f" 2>/dev/null | head -1 | tr -d '[:space:]')"
    if [ "$got" = "${v1}${v2}" ]; then
        log " OK  $n: [$old]->[${v1}TAB${v2}]"; APPLIED=$((APPLIED+1)); return 0
    fi
    log "FAIL $n: want[${v1}TAB${v2}] got[$got]"; FAILED=$((FAILED+1)); return 1
}

write_retry() {
    local f="$1" v="$2" n="${3:-$1}" i=0
    while [ "$i" -lt 3 ]; do
        write_val "$f" "$v" "$n"
        local got; got="$(cat "$f" 2>/dev/null | head -1 | tr -d '[:space:]')"
        [ "$got" = "$(echo "$v" | tr -d '[:space:]')" ] && return 0
        sleep 1; i=$((i+1))
    done
    return 1
}

summary() {
    local t=$((APPLIED+SKIPPED+FAILED))
    log "=== DONE: total=$t ok=$APPLIED skip=$SKIPPED fail=$FAILED ==="
    local ua uv
    ua="$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)"
    uv="$(cat /sys/class/power_supply/battery/voltage_now 2>/dev/null)"
    [ -n "$ua" ] && log "Battery: ${ua}uA @ ${uv}uV"
}

check_device() {
    local d; d="$(getprop ro.product.device 2>/dev/null)"
    case "$d" in RMX3700|RE585F|RE58D1L1) log "Device OK: $d"; return 0 ;; esac
    log "WARN: unknown device $d"
}
