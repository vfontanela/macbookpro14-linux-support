#!/usr/bin/env bash
# Install the T1Bridge .deb files from this directory on Debian 13 / Ubuntu 26.04.
#   sudo ./install.sh
# apt shows the transaction and asks before changing anything.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
state=/var/lib/t1bridge-port

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
model=$(cat /sys/class/dmi/id/product_name)
case $model in
  MacBookPro13,2|MacBookPro13,3|MacBookPro14,2|MacBookPro14,3) ;;
  *) echo "unsupported model: $model (T1 MacBook Pro with Touch Bar only)" >&2; exit 1 ;;
esac
[[ $(dpkg --print-architecture) == amd64 ]] || { echo "amd64 only" >&2; exit 1; }
(cd "$here" && sha256sum -c --quiet SHA256SUMS) || { echo "checksum mismatch" >&2; exit 1; }

# The folder name says which release these packages were built for.
. /etc/os-release
case "$(basename "$here"):$ID:$VERSION_ID" in
  debian-13:debian:13|ubuntu-26.04:ubuntu:26.04) ;;
  *) echo "these packages are for $(basename "$here"), this system is $ID $VERSION_ID" >&2; exit 1 ;;
esac

# Always: T1Bridge itself and the patched runtime pair. Other rebuilt binary
# packages (-dev, -tod1, gir, docs) only replace ones already installed, so an
# exact-version dependent is never removed or left behind.
always=(t1bridge t1bridge-dkms libfprint-2-2 fprintd libpam-fprintd)
debs=()
holds=()
for deb in "$here"/*.deb; do
  name=$(dpkg-deb -f "$deb" Package)
  case $name in *-dbgsym) continue ;; esac
  if printf '%s\n' "${always[@]}" | grep -qx "$name" ||
     dpkg-query -W -f='${Status}' "$name" 2>/dev/null | grep -q 'ok installed'; then
    debs+=("$deb")
    [[ $name == t1bridge* ]] || holds+=("$name")
  fi
done

apt-get install ${ASSUME_YES:+-y} "${debs[@]}"

# Keep distribution updates from silently replacing the patched libfprint/fprintd.
# Record the holds this script added so removal can undo exactly those.
install -d -m 0755 "$state"
for name in "${holds[@]}"; do
  if apt-mark showhold | grep -qE "^$name(:amd64)?$"; then
    echo "hold: $name already held (left as is)"
    continue
  fi
  apt-mark hold "$name" >/dev/null
  apt-mark showhold | grep -qE "^$name(:amd64)?$" || { echo "apt-mark hold $name failed" >&2; exit 1; }
  grep -qx "$name" "$state/held" 2>/dev/null || echo "$name" >> "$state/held"
done

if [[ -n ${SUDO_USER:-} ]]; then usermod -aG t1bridge "$SUDO_USER"; fi

echo
echo "Holds recorded in $state/held. Fingerprint PAM is NOT enabled by this script;"
echo "after enrolling, with a root shell open: sudo pam-auth-update --enable fprintd"
echo "Installed. Reboot, then follow the guide (import, enroll, PAM)."
