#!/bin/bash
# Write the BCM43602 board NVRAM for this MacBookPro14,2, with its own
# permanent MAC address (install), or delete it again (remove).
set -u
name=brcmfmac43602-mbp14-2-nvram
template=/usr/share/$name/brcmfmac43602-pcie.MacBookPro14,2.txt.in
target="/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt"
backup=/var/lib/$name/previous.txt
marker="# $name: generated; delete this line to keep local edits"

case ${1:-} in
install)
  [[ $(cat /sys/class/dmi/id/product_name 2>/dev/null) == MacBookPro14,2 ]] ||
    { echo "$name: not a MacBookPro14,2, nothing installed"; exit 0; }
  if [[ -e $target ]] && ! head -1 "$target" | grep -qxF "$marker"; then
    if [[ ! -e $backup ]]; then
      install -D -m 644 "$target" "$backup"
      echo "$name: previous NVRAM saved as $backup"
    fi
  fi
  mkdir -p "${target%/*}"
  mac=
  for d in /sys/class/net/*; do
    [[ $(cat "$d/device/vendor" 2>/dev/null) == 0x14e4 && $(cat "$d/device/device" 2>/dev/null) == 0x43ba ]] || continue
    mac=$(ethtool -P "${d##*/}" 2>/dev/null | awk '{print $NF}')
  done
  if [[ $mac =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ && $mac != 00:00:00:00:00:00 ]]; then
    { echo "$marker"; sed "s/@MACADDR@/$mac/" "$template"; } > "$target.new"
  else
    # No interface yet: the firmware then uses the address stored on the chip.
    echo "$name: permanent MAC not found; written without macaddr"
    { echo "$marker"; grep -v '^macaddr=' "$template"; } > "$target.new"
  fi
  chmod 644 "$target.new"
  mv "$target.new" "$target"
  echo "$name: NVRAM installed, reboot to enable 5 GHz"
  ;;
remove)
  if [[ -e $target ]] && head -1 "$target" | grep -qxF "$marker"; then
    rm -f "$target"
    if [[ -e $backup ]]; then mv "$backup" "$target"; echo "$name: previous NVRAM restored"; fi
  fi
  ;;
esac
