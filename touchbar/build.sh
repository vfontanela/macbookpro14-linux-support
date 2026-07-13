#!/bin/bash
# build.sh - assembles the .deb package from this repo's source tree.
#
# Usage: ./build.sh [version]
#   version defaults to 1.0-2 (Debian package version; the DKMS module
#   version itself is set independently in src/dkms.conf)
set -euo pipefail

VERSION="${1:-1.0-2}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(mktemp -d)"
PKGROOT="$BUILD_DIR/pkgroot"
MOD_VERSION="0.3"   # must match PACKAGE_VERSION in src/dkms.conf
MOD_NAME="mbp-t1-touchbar"

trap 'rm -rf "$BUILD_DIR"' EXIT

echo "==> Assembling package tree in $PKGROOT"
mkdir -p "$PKGROOT"/DEBIAN
mkdir -p "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/linux"
mkdir -p "$PKGROOT"/etc/modprobe.d
mkdir -p "$PKGROOT"/etc/modules-load.d
mkdir -p "$PKGROOT"/etc/udev/rules.d
mkdir -p "$PKGROOT"/lib/systemd/system
mkdir -p "$PKGROOT/usr/lib/${MOD_NAME}"
mkdir -p "$PKGROOT/usr/share/doc/${MOD_NAME}-dkms"

# kernel module source
cp "$ROOT_DIR"/src/*.c "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/"
cp "$ROOT_DIR"/src/linux/apple-ibridge.h "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/linux/"
cp "$ROOT_DIR"/src/Makefile "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/"
cp "$ROOT_DIR"/src/dkms.conf "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/"

# runtime automation
cp "$ROOT_DIR"/scripts/bind-touchbar.sh "$PKGROOT/usr/lib/${MOD_NAME}/"
cp "$ROOT_DIR"/systemd/mbp-t1-touchbar-bind.service "$PKGROOT"/lib/systemd/system/
cp "$ROOT_DIR"/udev/99-mbp-t1-touchbar.rules "$PKGROOT"/etc/udev/rules.d/
cp "$ROOT_DIR"/modprobe.d/mbp-t1-touchbar.conf "$PKGROOT"/etc/modprobe.d/
cp "$ROOT_DIR"/modules-load.d/mbp-t1-touchbar.conf "$PKGROOT"/etc/modules-load.d/

# debian control files
cp "$ROOT_DIR"/debian/control "$PKGROOT"/DEBIAN/control
cp "$ROOT_DIR"/debian/postinst "$PKGROOT"/DEBIAN/postinst
cp "$ROOT_DIR"/debian/prerm "$PKGROOT"/DEBIAN/prerm
cp "$ROOT_DIR"/debian/postrm "$PKGROOT"/DEBIAN/postrm
cp "$ROOT_DIR"/debian/conffiles "$PKGROOT"/DEBIAN/conffiles
sed -i "s/^Version: .*/Version: ${VERSION}/" "$PKGROOT"/DEBIAN/control

cp "$ROOT_DIR"/README.md "$PKGROOT/usr/share/doc/${MOD_NAME}-dkms/README.md" 2>/dev/null || true
cp "$ROOT_DIR"/LICENSE-NOTES.txt "$PKGROOT/usr/share/doc/${MOD_NAME}-dkms/copyright" 2>/dev/null || true

echo "==> Setting permissions"
chmod 0755 "$PKGROOT"/DEBIAN/postinst "$PKGROOT"/DEBIAN/prerm "$PKGROOT"/DEBIAN/postrm
chmod 0755 "$PKGROOT/usr/lib/${MOD_NAME}/bind-touchbar.sh"
chmod 0644 "$PKGROOT"/DEBIAN/control "$PKGROOT"/DEBIAN/conffiles
chmod 0644 "$PKGROOT"/lib/systemd/system/mbp-t1-touchbar-bind.service
chmod 0644 "$PKGROOT"/etc/udev/rules.d/99-mbp-t1-touchbar.rules
chmod 0644 "$PKGROOT"/etc/modprobe.d/mbp-t1-touchbar.conf
chmod 0644 "$PKGROOT"/etc/modules-load.d/mbp-t1-touchbar.conf
chmod 0644 "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}"/*.c \
           "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/linux"/*.h \
           "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/Makefile" \
           "$PKGROOT/usr/src/${MOD_NAME}-${MOD_VERSION}/dkms.conf"
find "$PKGROOT" -type d -exec chmod 0755 {} \;

echo "==> Syntax-checking shell scripts"
bash -n "$PKGROOT"/DEBIAN/postinst
bash -n "$PKGROOT"/DEBIAN/prerm
bash -n "$PKGROOT"/DEBIAN/postrm
bash -n "$PKGROOT/usr/lib/${MOD_NAME}/bind-touchbar.sh"

OUT="$ROOT_DIR/${MOD_NAME}-dkms_${VERSION}_all.deb"
echo "==> Building $OUT"
dpkg-deb --root-owner-group --build "$PKGROOT" "$OUT"

echo "==> Done:"
dpkg-deb -I "$OUT"
