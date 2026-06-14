#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

sec "MODEM POWER PREFERENCE"

setprop persist.oplus.qspa.modem enabled 2>/dev/null

if [ -f "/sys/class/net/wlan0/operstate" ]; then
    write_val "/proc/sys/net/ipv4/tcp_mtu_probing" "1" "tcp_mtu_probing"
fi

setprop persist.sys.oplus.network.nwpower.screenoff.wifienabled true 2>/dev/null

setprop vendor.perf.iop_v3.enable false 2>/dev/null

log "Modem v3.0 done"
