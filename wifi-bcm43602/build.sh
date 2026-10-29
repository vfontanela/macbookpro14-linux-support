#!/bin/bash
# Build brcmfmac43602-mbp14-2-nvram (.rpm and .deb).
#   bash wifi-bcm43602/build.sh OUTDIR        needs rpmbuild, dpkg-deb
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../lib/package.sh"

NAME=brcmfmac43602-mbp14-2-nvram VERSION=2.0 RELEASE=1 LICENSE=LicenseRef-unspecified
SUMMARY="2.4 and 5 GHz Wi-Fi (BCM43602 board NVRAM) for the MacBookPro14,2"
DESCRIPTION="The complete calibrated MacBookPro14,2 board NVRAM that brcmfmac needs
for the BCM43602 to work on both bands. On installation the permanent MAC
address of the machine is filled in. An existing NVRAM file is saved and
restored on removal. Does nothing on other models."
RPM_REQUIRES="ethtool"
DEB_DEPENDS="ethtool"
SETUP=/usr/libexec/$NAME/setup

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ROOT=$work/root
mkdir -p "$ROOT/usr/share/$NAME" "$ROOT/usr/libexec/$NAME"
cp "$here/brcmfmac43602-pcie.MacBookPro14,2.txt.in" "$ROOT/usr/share/$NAME/"
install -m 755 "$here/setup.sh" "$ROOT$SETUP"
RPM_FILES="/usr/share/$NAME
/usr/libexec/$NAME"
make_packages "$1"
