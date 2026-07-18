#!/bin/bash
# build.sh - assembles the .deb package from this repo's source tree.
set -euo pipefail

VERSION="${1:-1.0-1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(mktemp -d)"
PKGROOT="$BUILD_DIR/pkgroot"
MOD_NAME="snd_hda_macbookpro"
MOD_VERSION="1.0"   # must match PACKAGE_VERSION in src/dkms.conf

trap 'rm -rf "$BUILD_DIR"' EXIT

echo "==> Assembling package tree in $PKGROOT"
mkdir -p "$PKGROOT"/DEBIAN
mkdir -p "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}"
mkdir -p "$PKGROOT/usr/share/doc/mbp-cirrus-audio-dkms"

cp -a "$ROOT_DIR"/src/. "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/"

cp "$ROOT_DIR"/debian/control "$PKGROOT"/DEBIAN/control
cp "$ROOT_DIR"/debian/postinst "$PKGROOT"/DEBIAN/postinst
cp "$ROOT_DIR"/debian/prerm "$PKGROOT"/DEBIAN/prerm
cp "$ROOT_DIR"/debian/postrm "$PKGROOT"/DEBIAN/postrm
sed -i "s/^Version: .*/Version: ${VERSION}/" "$PKGROOT"/DEBIAN/control

cp "$ROOT_DIR"/README.md "$PKGROOT"/usr/share/doc/mbp-cirrus-audio-dkms/ 2>/dev/null || true
cp -r "$ROOT_DIR"/docs "$PKGROOT"/usr/share/doc/mbp-cirrus-audio-dkms/ 2>/dev/null || true

echo "==> Setting permissions"
chmod 0755 "$PKGROOT"/DEBIAN/postinst "$PKGROOT"/DEBIAN/prerm "$PKGROOT"/DEBIAN/postrm
chmod 0755 "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}"/install.cirrus.driver.sh \
           "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}"/install.cirrus.driver.pre617.sh \
           "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}"/dkms.sh
find "$PKGROOT" -type d -exec chmod 0755 {} \;

echo "==> Syntax-checking shell scripts"
bash -n "$PKGROOT"/DEBIAN/postinst
bash -n "$PKGROOT"/DEBIAN/prerm
bash -n "$PKGROOT"/DEBIAN/postrm
bash -n "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/install.cirrus.driver.sh"
bash -n "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/dkms.sh"

OUT="$ROOT_DIR/mbp-cirrus-audio-dkms_${VERSION}_all.deb"
echo "==> Building $OUT"
dpkg-deb --root-owner-group --build "$PKGROOT" "$OUT"

echo "==> Done:"
dpkg-deb -I "$OUT"
