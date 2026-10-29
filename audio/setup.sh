#!/bin/bash
# Register and build the CS8409 driver with DKMS (install), or unregister it
# (remove). Run by the package scripts.
set -u
name=snd_hda_macbookpro
version=@VERSION@

case ${1:-} in
install)
  [[ $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) == "Apple Inc." ]] ||
    { echo "$name: not an Apple computer, nothing built"; exit 0; }
  # A copy installed by hand with upstream's dkms.sh builds the same module.
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
  echo "$name: building for $kver (downloads this kernel's sound sources, takes a few minutes)"
  if dkms install -m $name -v "$version" -k "$kver" >/dev/null; then
    echo "$name: done, reboot to use the internal speakers and microphone"
  else
    echo "$name: WARNING: build failed, see /var/lib/dkms/$name/$version/build/make.log"
  fi
  ;;
remove)
  dkms remove -m $name -v "$version" --all >/dev/null 2>&1 || :
  ;;
esac
