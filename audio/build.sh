#!/bin/bash
# Build mbp-cirrus-audio-dkms (.rpm and .deb) from the pinned upstream driver.
#   bash audio/build.sh OUTDIR        needs git, rpmbuild, dpkg-deb
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../lib/package.sh"

upstream=https://github.com/davidjo/snd_hda_macbookpro.git
commit=6c324f6c9262faa853fdd74d798c5686937a9d0f   # 2026-08-10

NAME=mbp-cirrus-audio-dkms VERSION=2.0 RELEASE=1 LICENSE=GPL-2.0-only
SUMMARY="Internal speakers and microphone (Cirrus CS8409) for 2016-2017 MacBook Pro"
DESCRIPTION="DKMS package of davidjo/snd_hda_macbookpro (commit ${commit:0:7}),
which patches the kernel's CS8409 codec driver for the Apple amplifiers.
Each build downloads the sound sources of the running kernel (kernel.org,
or the linux-source package on Ubuntu). Needs Linux 6.17 or newer."
RPM_REQUIRES="dkms, gcc, make, patch, wget, xz, tar, kernel-devel"
DEB_DEPENDS="dkms, build-essential, patch, wget, xz-utils"
DEB_RECOMMENDS="linux-source"   # Ubuntu builds from it
SETUP=/usr/libexec/$NAME/setup

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone -q "$upstream" "$work/upstream"
ROOT=$work/root
src=$ROOT/usr/src/snd_hda_macbookpro-$VERSION
mkdir -p "$src" "$ROOT/usr/libexec/$NAME"
git -C "$work/upstream" archive "$commit" | tar -x -C "$src"
rm -rf "$src/tests" "$src/.gitignore"
sed -i "s/^PACKAGE_VERSION=.*/PACKAGE_VERSION=\"$VERSION\"/" "$src/dkms.conf"
sed "s/@VERSION@/$VERSION/" "$here/setup.sh" > "$ROOT$SETUP"
chmod 755 "$ROOT$SETUP"
RPM_FILES="/usr/src/snd_hda_macbookpro-$VERSION
/usr/libexec/$NAME"
make_packages "$1"
