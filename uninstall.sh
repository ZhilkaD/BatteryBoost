#!/system/bin/sh
set +e
BACKUP_DIR="/data/adb/batteryboost_backup"
BACKUP_MAP="$BACKUP_DIR/map.txt"
echo "[BatteryBoost v3.0] Uninstalling..."
if [ -f "$BACKUP_MAP" ]; then
    while IFS='|' read -r orig bname; do
        [ -z "$orig" ] && continue
        bf="$BACKUP_DIR/$bname"
        [ -f "$bf" ] && [ -e "$orig" ] && cat "$bf" > "$orig" 2>/dev/null && echo "Restored: $orig"
    done < "$BACKUP_MAP"
fi

ORMS_BIN="/odm/bin/hw/vendor.oplus.hardware.ormsHalService-aidl-service"
umount "$ORMS_BIN" 2>/dev/null && echo "ORMS bind mount removed"

rm -rf "$BACKUP_DIR" 2>/dev/null
rm -f /data/local/tmp/batteryboost*.log 2>/dev/null
echo "[BatteryBoost v3.0] Done. Reboot recommended."
