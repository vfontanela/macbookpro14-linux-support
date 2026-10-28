#!/usr/bin/env bash
# Install the T1Bridge RPMs and enable the services on Fedora.
#   sudo ./install.sh [rpm-dir]
# Without rpm-dir: the script's own directory when it holds RPMs (a release
# folder), otherwise the invoking user's ~/rpmbuild/RPMS.
# dnf shows the transaction and asks before changing anything; review the
# "Removing" section (the legacy mbp-t1-touchbar-dkms is expected there).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
state=/var/lib/t1bridge-port

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
model=$(cat /sys/class/dmi/id/product_name)
case $model in
  MacBookPro13,2|MacBookPro13,3|MacBookPro14,2|MacBookPro14,3) ;;
  *) echo "unsupported model: $model (T1 MacBook Pro with Touch Bar only)" >&2; exit 1 ;;
esac
[[ $(uname -m) == x86_64 ]] || { echo "x86_64 only" >&2; exit 1; }

if [[ -n ${1:-} ]]; then
  rpms=$(realpath "$1")
elif compgen -G "$here/*.rpm" >/dev/null; then
  rpms=$here
else
  rpms=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)/rpmbuild/RPMS
fi
if [[ -f $rpms/SHA256SUMS ]]; then
  (cd "$rpms" && sha256sum -c --quiet SHA256SUMS) || { echo "checksum mismatch in $rpms" >&2; exit 1; }
else
  echo "warning: no SHA256SUMS in $rpms; installing unverified local build output" >&2
fi

mapfile -t pkgs < <(find "$rpms" -name '*.rpm' \( -name 't1bridge-*' \
  -o -name 'libfprint-1.94*t1bridge*' -o -name 'fprintd-1.94*t1bridge*' \
  -o -name 'fprintd-pam-1.94*t1bridge*' \) ! -name '*-debug*' ! -name '*.src.rpm' | sort)
# Replace every installed Fedora subpackage of the pair: an exact-release
# dependent such as libfprint-devel would otherwise block or be removed.
if rpm -q libfprint-devel >/dev/null 2>&1; then
  mapfile -t -O "${#pkgs[@]}" pkgs < <(find "$rpms" -name 'libfprint-devel-1.94*t1bridge*.rpm')
fi
[[ ${#pkgs[@]} -gt 0 ]] || { echo "no RPMs under $rpms; run build.sh first" >&2; exit 1; }

# One build for this Fedora release and architecture, one version per package.
fedora=$(rpm -E %fedora)
names=()
for p in "${pkgs[@]}"; do
  [[ $(rpm -qp --qf '%{RELEASE}' "$p" 2>/dev/null) == *".fc$fedora" ]] ||
    { echo "$(basename "$p") is not built for Fedora $fedora" >&2; exit 1; }
  arch=$(rpm -qp --qf '%{ARCH}' "$p" 2>/dev/null)
  [[ $arch == x86_64 || $arch == noarch ]] || { echo "$(basename "$p"): wrong arch $arch" >&2; exit 1; }
  names+=("$(rpm -qp --qf '%{NAME}' "$p" 2>/dev/null)")
done
dup=$(printf '%s\n' "${names[@]}" | sort | uniq -d)
[[ -z $dup ]] || { echo "several versions of: $dup -- keep one per package in $rpms" >&2; exit 1; }

# t1bridge-dkms conflicts with the legacy Touch Bar driver, which keeps the T1
# in a USB configuration without the Secure Enclave interface.
dnf install --allowerasing ${ASSUME_YES:+-y} "${pkgs[@]}"

# Keep Fedora updates from silently replacing the patched pair. Record which
# locks this script added so removal can undo exactly those.
install -d -m 0755 "$state"
for name in libfprint libfprint-devel fprintd fprintd-pam; do
  rpm -q "$name" >/dev/null 2>&1 || continue
  if dnf versionlock list 2>/dev/null | grep -qx "Package name: $name"; then
    echo "versionlock: $name already locked (left as is)"
    continue
  fi
  dnf versionlock add "$name"
  dnf versionlock list | grep -qx "Package name: $name" || { echo "versionlock for $name failed" >&2; exit 1; }
  grep -qx "$name" "$state/versionlocked" 2>/dev/null || echo "$name" >> "$state/versionlocked"
done

systemd-sysusers t1bridge.conf
systemd-tmpfiles --create t1bridge.conf
if [[ -n ${SUDO_USER:-} ]]; then usermod -aG t1bridge "$SUDO_USER"; fi
systemctl daemon-reload
systemctl enable t1-touchbar-hw.service t1-touchid-auth.socket t1bridge-fingerprint.socket
systemctl --global enable t1-touchbar.service

echo
if authselect current 2>/dev/null | grep -q with-fingerprint; then
  echo "PAM: authselect feature with-fingerprint is enabled (fingerprint, then password)."
else
  echo "PAM: fingerprint login is NOT enabled. After enrolling, with a root shell open:"
  echo "     sudo authselect enable-feature with-fingerprint && sudo authselect apply-changes"
fi
echo "Installed. Reboot, then follow the guide (import, enroll, PAM)."
