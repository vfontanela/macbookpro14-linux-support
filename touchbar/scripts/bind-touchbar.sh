#!/bin/bash
# mbp-t1-touchbar: activate the T1 iBridge Touch Bar.
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

# Find a physical HID device belonging to USB interface 1.3
find_display_physical_hid() {
    local d real

    for d in /sys/bus/hid/devices/0003:05AC:8600.*; do
        [[ -e "$d" ]] || continue
        real="$(readlink -f "$d")"
        [[ "$real" == *"/${BUSID}:1.3/"* ]] || continue
        echo "$(basename "$d")"
        return 0
    done
    return 1
}

# Find virtual Touch Bar HID 0301 descending from USB interface 1.3
find_display_virtual_hid() {
    local d real

    for d in /sys/bus/hid/devices/0003:1D6B:0301.*; do
        [[ -e "$d" ]] || continue
        real="$(readlink -f "$d")"
        [[ "$real" == *"/${BUSID}:1.3/"* ]] || continue
        echo "$(basename "$d")"
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

    if [[ "$current" == "$wanted" ]]; then
        return 0
    fi

    if [[ -n "$current" && -w "/sys/bus/hid/drivers/$current/unbind" ]]; then
        printf %s "$devid" > "/sys/bus/hid/drivers/$current/unbind" || return 1
        sleep 0.2
    fi

    printf %s "$devid" > "/sys/bus/hid/drivers/$wanted/bind" || return 1
    [[ "$(basename "$(readlink -f "$path/driver")")" == "$wanted" ]]
}

modprobe apple-ibridge || { log "failed to load apple-ibridge"; exit 1; }
modprobe apple-ib-tb || { log "failed to load apple-ib-tb"; exit 1; }
modprobe apple-ib-als 2>/dev/null || true

BUSID=""
for _ in $(seq 1 15); do
    BUSID="$(find_busid "$IDPRODUCT_IBRIDGE" || true)"
    [[ -n "$BUSID" ]] && break

    if find_busid "$IDPRODUCT_RECOVERY" >/dev/null; then
        log "T1 chip is in recovery mode (05ac:1281): boot macOS to restore its firmware, then reboot into Linux."
        exit 1
    fi
    sleep 1
done

if [[ -z "$BUSID" ]]; then
    log "Apple iBridge (05ac:8600) not found."
    exit 1
fi

log "found iBridge at $BUSID; reprobe"

if [[ -L "/sys/bus/usb/devices/$BUSID/driver" ]]; then
    USB_DRIVER="$(readlink -f "/sys/bus/usb/devices/$BUSID/driver")"
    printf %s "$BUSID" > "$USB_DRIVER/unbind" || { log "USB unbind failed"; exit 1; }
fi
sleep 1
printf %s "$BUSID" > /sys/bus/usb/drivers_probe || { log "USB reprobe failed"; exit 1; }
sleep 1

# The second HID interface (USB interface 1.3) contains the
# Touch Bar display reports. On newer kernels hid-sensor-hub may
# claim it before apple-ibridge-hid.
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

# apple-ibridge-hid now creates a virtual 1d6b:0301 from that
# interface. hid-sensor-hub may claim this one too.
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

# The driver creates controls on the mode HID (usually :1.2), once
# both mode and display interfaces are attached. Scope to this iBridge.
for _ in $(seq 1 20); do
    for d in /sys/bus/hid/devices/0003:1D6B:0301.*; do
        [[ -e "$d" ]] || continue
        real="$(readlink -f "$d")"
        case "$real" in
            *"/${BUSID}:1.2/"*|*"/${BUSID}:1.3/"*) ;;
            *) continue ;;
        esac
        [[ "$(basename "$(readlink -f "$d/driver")")" == apple-ib-touchbar ]] || continue
        if [[ -f "$d/idle_timeout" && -f "$d/dim_timeout" && -f "$d/fnmode" ]]; then
            log "Touch Bar activated successfully at $d"
            exit 0
        fi
    done
    sleep 0.25
done
log "bindings completed, but this iBridge did not expose Touch Bar control attributes"
exit 1
