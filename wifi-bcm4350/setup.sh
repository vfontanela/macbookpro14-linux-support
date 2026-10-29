#!/bin/bash
# Register and build the patched brcmfmac with DKMS (install), or unregister it
# (remove). Run by the package scripts. Only acts on a BCM4350 (14e4:43a3).
set -u
name=brcmfmac-bcm4350-dfs
version=@VERSION@

has_bcm4350() {
  local d
  for d in /sys/bus/pci/devices/*; do
    [[ $(cat "$d/vendor") == 0x14e4 && $(cat "$d/device") == 0x43a3 ]] && return 0
  done
  return 1
}

case ${1:-} in
install)
  has_bcm4350 || { echo "$name: no BCM4350 Wi-Fi (MacBookPro14,1) here, nothing built"; exit 0; }
  for v in $(dkms status -m $name 2>/dev/null | sed -n "s|^$name/\([^,:]*\).*|\1|p" | sort -u); do
    [[ $v == "$version" ]] && continue
    echo "$name: replacing previously installed version $v"
    dkms remove -m $name -v "$v" --all >/dev/null 2>&1 || :
  done
  dkms status -m $name -v "$version" | grep -q . || dkms add -m $name -v "$version" >/dev/null
  kver=$(uname -r)
  if [[ ! -d /lib/modules/$kver/build ]]; then
    echo "$name: install the kernel headers for $kver, then run: sudo dkms autoinstall"
    exit 0
  fi
  if dkms install -m $name -v "$version" -k "$kver" >/dev/null; then
    echo "$name: done, reboot to see DFS channels (5 GHz 100-144)"
  else
    echo "$name: WARNING: build failed for $kver; the stock brcmfmac stays in use (Wi-Fi works, without DFS)."
    echo "  See /var/lib/dkms/$name/$version/build/make.log"
  fi
  ;;
remove)
  dkms remove -m $name -v "$version" --all >/dev/null 2>&1 || :
  ;;
esac
