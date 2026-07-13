#!/bin/bash
# mbp-t1-touchbar: (re)bind the Apple iBridge (T1) USB device to the
# apple-ibridge driver so the Touch Bar actually lights up.
#
# The apple-ibridge driver only registers a HID driver, not a full
# usb_driver, so the generic "usb" driver frequently grabs the device
# first. Unbinding it from "usb" and re-probing forces the kernel to
# hand it to apple-ibridge instead. This has to be redone after every
# (re)enumeration of the device, including resume from suspend, which
# is why this script is triggered both at boot and via udev.
set -u
LOG_TAG="mbp-t1-touchbar"
IDVENDOR="05ac"
IDPRODUCT_IBRIDGE="8600"
IDPRODUCT_RECOVERY="1281"

log() { logger -t "$LOG_TAG" "$1"; }

find_busid() {
    local want_pid="$1"
    for dev in /sys/bus/usb/devices/*; do
        local name
        name="$(basename "$dev")"
        # skip interface entries (e.g. "1-3:1.2"), we want the device itself
        [[ "$name" == *:* ]] && continue
        [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue
        local vid pid
        vid="$(cat "$dev/idVendor" 2>/dev/null)"
        pid="$(cat "$dev/idProduct" 2>/dev/null)"
        if [[ "$vid" == "$IDVENDOR" && "$pid" == "$want_pid" ]]; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

modprobe apple-ibridge 2>/dev/null
modprobe apple-ib-tb 2>/dev/null
modprobe apple-ib-als 2>/dev/null

BUSID=""
for _ in $(seq 1 15); do
    BUSID="$(find_busid "$IDPRODUCT_IBRIDGE" || true)"
    [[ -n "$BUSID" ]] && break
    if find_busid "$IDPRODUCT_RECOVERY" >/dev/null; then
        log "T1 chip is in recovery mode (05ac:1281): its firmware is missing. Boot macOS once so it can restore the T1 firmware, then reboot into Linux."
        exit 1
    fi
    sleep 1
done

if [[ -z "$BUSID" ]]; then
    log "Apple iBridge (05ac:8600) not found after waiting. Run 'lsusb' to check whether the T1 is present at all."
    exit 1
fi

log "found iBridge at USB bus id $BUSID, rebinding to apple-ibridge driver"
echo -n "$BUSID" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
sleep 1
echo -n "$BUSID" > /sys/bus/usb/drivers_probe 2>/dev/null
sleep 1

if lsusb -t 2>/dev/null | grep -q "05ac:8600"; then
    log "rebind OK, Touch Bar should be active. If it's still blank, try rebooting once."
else
    log "rebind attempted but couldn't verify via lsusb -t; check manually."
fi
