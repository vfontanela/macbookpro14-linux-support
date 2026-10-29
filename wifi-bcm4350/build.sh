#!/bin/bash
# Build brcmfmac-bcm4350-dfs-dkms (.rpm only) from src/.
#   bash wifi-bcm4350/build.sh OUTDIR        needs rpmbuild, dpkg-deb
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../lib/package.sh"

NAME=brcmfmac-bcm4350-dfs-dkms VERSION=2.0 RELEASE=1 LICENSE=ISC
SUMMARY="5 GHz DFS channels for the BCM4350 Wi-Fi of the MacBookPro14,1"
DESCRIPTION="DKMS package of the kernel's brcmfmac driver with BCM4350 added to
the ISO 3166 country-code fallback, so the firmware receives the regulatory
country and DFS channels 100-144 become usable. Built only when a BCM4350
(14e4:43a3) is present. The sources build on Linux 7.2."
RPM_REQUIRES="dkms, gcc, make, kernel-devel"
DEB_DEPENDS=none   # the sources only build on Linux 7.2 (Fedora)
SETUP=/usr/libexec/$NAME/setup

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ROOT=$work/root
src=$ROOT/usr/src/brcmfmac-bcm4350-dfs-$VERSION
mkdir -p "$src" "$ROOT/usr/libexec/$NAME"
cp -a "$here/src/." "$src/"
sed -i "s/^PACKAGE_VERSION=.*/PACKAGE_VERSION=\"$VERSION\"/" "$src/dkms.conf"
sed "s/@VERSION@/$VERSION/" "$here/setup.sh" > "$ROOT$SETUP"
chmod 755 "$ROOT$SETUP"
RPM_FILES="/usr/src/brcmfmac-bcm4350-dfs-$VERSION
/usr/libexec/$NAME"
make_packages "$1"
