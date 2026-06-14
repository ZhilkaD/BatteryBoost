#!/system/bin/sh
[ -z "$MODDIR" ] && return 1

SILVER_MASK="0f"

_apply_wifi_irq() {
    local cnt=0 fail=0 skip=0
    local patterns="pci0_wlan_ce_0 pci0_wlan_ce_1 pci0_wlan_ce_2 pci0_wlan_ce_3 pci0_wlan_grp_dp_0 pci0_wlan_grp_dp_1 wlan_wake_irq"
    for pat in $patterns; do
        local irqn af cur
        irqn="$(grep "$pat" /proc/interrupts 2>/dev/null | awk '{gsub(/:/, "", $1); print $1}' | head -1)"
        [ -z "$irqn" ] && { skip=$((skip+1)); continue; }
        af="/proc/irq/${irqn}/smp_affinity"
        [ -w "$af" ] || { log "WARN IRQ $irqn [$pat] not writable"; skip=$((skip+1)); continue; }
        cur="$(cat "$af" 2>/dev/null | tr -d ' \n')"
        if [ "$cur" = "$SILVER_MASK" ] || [ "$cur" = "0000000f" ]; then
            cnt=$((cnt+1)); continue
        fi
        echo "$SILVER_MASK" > "$af" 2>/dev/null
        local got; got="$(cat "$af" 2>/dev/null | tr -d ' \n')"
        if [ "$got" = "$SILVER_MASK" ] || [ "$got" = "0000000f" ]; then
            log " OK  IRQ $irqn [$pat] $cur->Silver"; cnt=$((cnt+1))
        else
            log "FAIL IRQ $irqn [$pat] got=$got"; fail=$((fail+1))
        fi
    done
    APPLIED=$((APPLIED+cnt)); FAILED=$((FAILED+fail)); SKIPPED=$((SKIPPED+skip))
    log "WiFi IRQ: ok=$cnt fail=$fail skip=$skip"
}

_apply_ufs_irq() {
    local irqn; irqn="$(grep "ufshcd" /proc/interrupts 2>/dev/null | awk '{gsub(/:/, "", $1); print $1}' | head -1)"
    [ -z "$irqn" ] && return
    local af="/proc/irq/${irqn}/smp_affinity"
    [ -w "$af" ] || return
    local cur; cur="$(cat "$af" 2>/dev/null | tr -d ' \n')"
    case "$cur" in 0f|0000000f|01|03|07)
        log " OK  UFS IRQ $irqn = Silver ($cur)"; return ;;
    esac
    echo "$SILVER_MASK" > "$af" 2>/dev/null
    log " OK  UFS IRQ $irqn: $cur->Silver"
    APPLIED=$((APPLIED+1))
}

_apply_touch_irq() {
    local irqn; irqn="$(grep "touch-00" /proc/interrupts 2>/dev/null | awk '{gsub(/:/, "", $1); print $1}' | head -1)"
    [ -z "$irqn" ] && return
    local af="/proc/irq/${irqn}/smp_affinity"
    [ -w "$af" ] || return
    local cur; cur="$(cat "$af" 2>/dev/null | tr -d ' \n')"
    if [ "$cur" = "$SILVER_MASK" ] || [ "$cur" = "0000000f" ]; then
        log " OK  Touch IRQ $irqn = Silver"; return
    fi
    echo "$SILVER_MASK" > "$af" 2>/dev/null
    local got; got="$(cat "$af" 2>/dev/null | tr -d ' \n')"
    if [ "$got" = "$SILVER_MASK" ] || [ "$got" = "0000000f" ]; then
        log " OK  Touch IRQ $irqn: $cur->Silver"; APPLIED=$((APPLIED+1))
    else
        log "WARN Touch IRQ $irqn got=$got"; SKIPPED=$((SKIPPED+1))
    fi
}

sec "IRQ AFFINITY"
_apply_wifi_irq
_apply_ufs_irq
_apply_touch_irq

log "IRQ v3.0 done"
