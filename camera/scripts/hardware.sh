#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Source this library; no hardware changes are performed here.
facetimehd_devices() {
    local dev vendor device
    for dev in /sys/bus/pci/devices/*; do
        [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
        read -r vendor < "$dev/vendor"
        read -r device < "$dev/device"
        if [[ "$vendor" == 0x14e4 && "$device" == 0x1570 ]]; then
            basename "$dev"
        fi
    done
}
facetimehd_require_hardware() {
    if [[ -z "$(facetimehd_devices)" ]]; then
        echo 'No supported FaceTime HD PCIe camera (14e4:1570). Nothing configured.' >&2
        echo 'USB/iBridge cameras use uvcvideo and do not need this package.' >&2
        return 1
    fi
}
facetimehd_video_nodes() {
    local bdf video real
    for bdf in $(facetimehd_devices); do
        for video in /sys/class/video4linux/video*; do
            [[ -e "$video" ]] || continue
            real=$(readlink -f "$video/device")
            case "$real/" in
                *"/$bdf/"*) [[ -c "/dev/${video##*/}" ]] && echo "/dev/${video##*/}" ;;
            esac
        done
    done
}
