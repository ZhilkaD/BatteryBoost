#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

sec "BLOCK I/O"
for dev in sda sdb sdc sdd sde sdf; do
    Q="/sys/block/$dev/queue"
    [ -d "$Q" ] || continue
    write_val "$Q/read_ahead_kb"  "128" "$dev read_ahead (1024->128)"
    write_val "$Q/iostats"          "0" "$dev iostats off"
    write_val "$Q/nr_requests"    "128" "$dev nr_req (62->128)"
    write_val "$Q/rq_affinity"      "2" "$dev rq_affinity (1->2)"
done

for dm in /sys/block/dm-*/queue; do
    [ -d "$dm" ] || continue
    dn="$(basename "$(dirname "$dm")")"
    write_val "$dm/read_ahead_kb" "128" "$dn read_ahead"
    write_val "$dm/iostats"         "0" "$dn iostats off"
done

[ -d "/sys/block/zram0/queue" ] && write_val "/sys/block/zram0/queue/read_ahead_kb" "4" "zram0 read_ahead"

sec "UFS"
for ufs in /sys/devices/platform/soc/*.ufshc; do
    [ -d "$ufs" ] || continue
    [ -f "$ufs/auto_hibern8" ] && {
        cur="$(cat "$ufs/auto_hibern8" 2>/dev/null)"
        [ "$cur" = "0" ] || [ -z "$cur" ] && write_val "$ufs/auto_hibern8" "5000" "UFS auto_hibern8"
        log " OK  UFS auto_hibern8 = $cur"
    }
    write_val "$ufs/clkgate_enable"  "1" "UFS clkgate"
    write_val "$ufs/clkscale_enable" "1" "UFS clkscale"
    break
done

log "I/O v3.0 done"
