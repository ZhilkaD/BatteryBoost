#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

VM="/proc/sys/vm"
sec "VM TUNING"
write_val "$VM/swappiness"                   "60" "swappiness (100->60)"
write_val "$VM/vfs_cache_pressure"           "80" "vfs_cache_pressure (100->80)"
write_val "$VM/dirty_background_ratio"        "8" "dirty_bg_ratio (5->8)"
write_val "$VM/dirty_ratio"                  "25" "dirty_ratio (20->25)"
write_val "$VM/dirty_expire_centisecs"     "4000" "dirty_expire (200->4000)"
write_val "$VM/dirty_writeback_centisecs"  "1500" "dirty_wb (500->1500)"
write_val "$VM/min_free_kbytes"           "16384" "min_free (11584->16384)"
write_val "$VM/extra_free_kbytes"         "24576" "extra_free (65536->24576)"
write_val "$VM/watermark_scale_factor"       "20" "watermark_scale (16->20)"
write_val "$VM/laptop_mode"                   "1" "laptop_mode"
write_val "$VM/stat_interval"                 "2" "stat_interval (1->2)"
write_val "$VM/compaction_proactiveness"     "20" "compaction_proact (10->20 less aggressive)"

sec "OPLUS MEM"
if [ -f "/proc/oplus_mem/dynamic_swappiness" ]; then
    echo "60 4096 80 2048" > /proc/oplus_mem/dynamic_swappiness 2>/dev/null
    got="$(cat /proc/oplus_mem/dynamic_swappiness 2>/dev/null | awk '{print $1}')"
    [ "$got" = "60" ] && { log " OK  oplus dynamic_swappiness"; APPLIED=$((APPLIED+1)); } \
                       || { log "WARN oplus dynamic_swappiness not changed (base=$got)"; SKIPPED=$((SKIPPED+1)); }
fi

if [ -f "/proc/oplus_mem/alloc_adjust_ctrl" ]; then
    old="$(cat /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null)"
    echo "0" > /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null
    got="$(cat /proc/oplus_mem/alloc_adjust_ctrl 2>/dev/null)"
    [ "$got" = "0" ] && log " OK  alloc_adjust_ctrl [$old]->[0] (stop oplus_mem override)" \
                      || log "WARN alloc_adjust_ctrl got=$got"
fi

sec "ZRAM COMPRESSION"
ZRAM="/sys/block/zram0"
if [ -d "$ZRAM" ] && [ -f "$ZRAM/comp_algorithm" ]; then
    old_alg="$(cat "$ZRAM/comp_algorithm" 2>/dev/null)"
    case "$old_alg" in
        *\[zstd\]*) log " OK  zram already zstd"; APPLIED=$((APPLIED+1)) ;;
        *) log "SKIP zram comp_algorithm (can't change on active swap, current: $old_alg)"; SKIPPED=$((SKIPPED+1)) ;;
    esac
else
    log "SKIP zram (no zram0)"
fi
    fi
else
    log "SKIP zram (no zram0)"
fi

log "Memory v3.0 done"
