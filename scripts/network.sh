#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

TCP="/proc/sys/net/ipv4"
sec "NETWORK TCP"
write_val "$TCP/tcp_slow_start_after_idle" "0" "tcp_slow_start off"
write_val "$TCP/tcp_fastopen"              "3" "tcp_fastopen (1->3)"
write_val "$TCP/tcp_keepalive_time"     "1800" "keepalive_time (7200->1800)"
write_val "$TCP/tcp_keepalive_intvl"      "30" "keepalive_intvl (75->30)"
write_val "$TCP/tcp_keepalive_probes"      "5" "keepalive_probes (9->5)"
write_val "$TCP/tcp_fin_timeout"          "30" "fin_timeout (60->30)"
write_val "$TCP/tcp_syn_retries"           "3" "syn_retries (4->3)"
write_val "$TCP/tcp_synack_retries"        "2" "synack_retries (3->2)"

sec "WIFI PCIe POWER"
PCIE="/sys/bus/pci/devices/0000:01:00.0/power/control"
if [ -e "$PCIE" ]; then
    cur="$(cat "$PCIE" 2>/dev/null)"
    [ "$cur" != "auto" ] && {
        echo "auto" > "$PCIE" 2>/dev/null
        got="$(cat "$PCIE" 2>/dev/null)"
        log " OK  PCIe power: [$cur]->[$got] (runtime suspend enabled)"
        APPLIED=$((APPLIED+1))
    } || log " OK  PCIe power already auto"
else
    log "SKIP PCIe power control (no device)"
fi

AUTOSUSPEND="/sys/bus/pci/devices/0000:01:00.0/power/autosuspend_delay_ms"
if [ -f "$AUTOSUSPEND" ]; then
    old="$(cat "$AUTOSUSPEND" 2>/dev/null)"
    echo "5000" > "$AUTOSUSPEND" 2>/dev/null
    got="$(cat "$AUTOSUSPEND" 2>/dev/null)"
    log " OK  PCIe autosuspend: [${old}ms]->[${got}ms]"
    APPLIED=$((APPLIED+1))
else
    log "SKIP PCIe autosuspend"
fi

sec "PCIe ASPM POWERSAVE"
ASPM="/sys/module/pcie_aspm/parameters/policy"
if [ -f "$ASPM" ]; then
    old="$(cat "$ASPM" 2>/dev/null | head -1)"
    echo "powersave" > "$ASPM" 2>/dev/null
    got="$(cat "$ASPM" 2>/dev/null | head -1)"
    case "$got" in
        *powersave*|*Powersave*) log " OK  PCIe ASPM: [$old]->[$got] (L0s+L1 enabled)"; APPLIED=$((APPLIED+1)) ;;
        *) log "WARN PCIe ASPM: wrote powersave got [$got] (may need boot param)" ;;
    esac
else
    log "SKIP PCIe ASPM policy (no sysfs)"
fi

L1ASPM="/sys/bus/pci/devices/0000:01:00.0/link/l1_aspm"
if [ -f "$L1ASPM" ]; then
    old="$(cat "$L1ASPM" 2>/dev/null)"
    echo "1" > "$L1ASPM" 2>/dev/null
    got="$(cat "$L1ASPM" 2>/dev/null)"
    [ "$got" = "1" ] && { log " OK  WiFi L1 ASPM: [$old]->[$got] (L1.2 deep sleep)"; APPLIED=$((APPLIED+1)); } \
                     || log "WARN WiFi L1 ASPM: want=1 got=$got"
else
    log "SKIP WiFi L1 ASPM (no sysfs)"
fi

log "Network v3.0 done"
