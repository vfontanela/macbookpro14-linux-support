#!/usr/bin/bash
# mbp-t1-touchbar: activate the T1 iBridge Touch Bar.
#
# Besides reprobeing the iBridge USB device, force the HID interface that
# carries the Touch Bar display reports through apple-ibridge-hid and then
# apple-ib-touchbar. On Fedora 44 / Linux 7.2.8, hid-sensor-hub can win both
# binding races and leave the Touch Bar dark even though the modules are loaded.
set -u

LOG_TAG="mbp-t1-touchbar"
IDVENDOR="05ac"
IDPRODUCT_IBRIDGE="8600"
IDPRODUCT_RECOVERY="1281"

log() { logger -t "$LOG_TAG" "$1"; }

find_busid() {
    local want_pid="$1"
    local dev name vid pid
    for dev in /sys/bus/usb/devices/*; do
        name="$(basename "$dev")"
        [[ "$name" == *:* ]] && continue
        [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue
        vid="$(cat "$dev/idVendor" 2>/dev/null)"
        pid="$(cat "$dev/idProduct" 2>/dev/null)"
        if [[ "$vid" == "$IDVENDOR" && "$pid" == "$want_pid" ]]; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

find_display_physical_hid() {
    local d real
    for d in /sys/bus/hid/devices/0003:05AC:8600.*; do
        [[ -e "$d" ]] || continue
        real="$(readlink -f "$d")"
        [[ "$real" == *"/${BUSID}:1.3/"* ]] || continue
        basename "$d"
        return 0
    done
    return 1
}

find_display_virtual_hid() {
    local d real
    for d in /sys/bus/hid/devices/0003:1D6B:0301.*; do
        [[ -e "$d" ]] || continue
        real="$(readlink -f "$d")"
        [[ "$real" == *"/${BUSID}:1.3/"* ]] || continue
        basename "$d"
        return 0
    done
    return 1
}

rebind_hid() {
    local devid="$1"
    local wanted="$2"
    local path="/sys/bus/hid/devices/$devid"
    local current=""

    [[ -e "$path" ]] || return 1

    if [[ -L "$path/driver" ]]; then
        current="$(basename "$(readlink -f "$path/driver")")"
    fi

    [[ "$current" == "$wanted" ]] && return 0

    if [[ -n "$current" && -w "/sys/bus/hid/drivers/$current/unbind" ]]; then
        echo -n "$devid" > "/sys/bus/hid/drivers/$current/unbind"
        sleep 0.2
    fi

    echo -n "$devid" > "/sys/bus/hid/drivers/$wanted/bind"
}

modprobe apple-ibridge 2>/dev/null || true
modprobe apple-ib-tb 2>/dev/null || true
modprobe apple-ib-als 2>/dev/null || true

BUSID=""
for _ in $(seq 1 15); do
    BUSID="$(find_busid "$IDPRODUCT_IBRIDGE" || true)"
    [[ -n "$BUSID" ]] && break
    if find_busid "$IDPRODUCT_RECOVERY" >/dev/null; then
        log "T1 chip is in recovery mode (05ac:1281). Boot macOS once to restore its firmware."
        exit 1
    fi
    sleep 1
done

if [[ -z "$BUSID" ]]; then
    log "Apple iBridge (05ac:8600) not found."
    exit 1
fi

log "found iBridge at $BUSID; reprobe"
echo -n "$BUSID" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null || true
sleep 1
echo -n "$BUSID" > /sys/bus/usb/drivers_probe 2>/dev/null || true
sleep 1

PHYS=""
for _ in $(seq 1 20); do
    PHYS="$(find_display_physical_hid || true)"
    [[ -n "$PHYS" ]] && break
    sleep 0.25
done

if [[ -z "$PHYS" ]]; then
    log "display HID on ${BUSID}:1.3 not found"
    exit 1
fi

log "binding display physical HID $PHYS to apple-ibridge-hid"
rebind_hid "$PHYS" "apple-ibridge-hid" || {
    log "failed to bind $PHYS to apple-ibridge-hid"
    exit 1
}

VIRT=""
for _ in $(seq 1 20); do
    VIRT="$(find_display_virtual_hid || true)"
    [[ -n "$VIRT" ]] && break
    sleep 0.25
done

if [[ -z "$VIRT" ]]; then
    log "virtual display Touch Bar HID not found"
    exit 1
fi

log "binding display virtual HID $VIRT to apple-ib-touchbar"
rebind_hid "$VIRT" "apple-ib-touchbar" || {
    log "failed to bind $VIRT to apple-ib-touchbar"
    exit 1
}

sleep 0.5
if find /sys/bus/hid/devices/0003:1D6B:0301.* -maxdepth 1 -type f -name idle_timeout -print -quit 2>/dev/null | grep -q .; then
    log "Touch Bar activated successfully"
    exit 0
fi

log "bindings completed, but Touch Bar control attributes were not exposed"
exit 1
