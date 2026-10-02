#!/bin/bash
# Build an RPM from this checkout without root. Output defaults to ./dist.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(realpath -m "${1:-$ROOT_DIR/dist}")"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$OUT" "$BUILD_DIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
STAGE="$BUILD_DIR/mbp-t1-touchbar-0.3"
mkdir -p "$STAGE"
cp -a "$ROOT_DIR"/{scripts,systemd,udev,modprobe.d,modules-load.d,docs,README.md,LICENSE} "$STAGE/"
mkdir -p "$STAGE/src/linux"
cp "$ROOT_DIR"/src/{apple-ibridge.c,apple-ib-tb.c,apple-ib-als.c,Makefile,dkms.conf} "$STAGE/src/"
cp "$ROOT_DIR/src/linux/apple-ibridge.h" "$STAGE/src/linux/"
tar -czf "$BUILD_DIR/SOURCES/mbp-t1-touchbar-0.3.tar.gz" -C "$BUILD_DIR" mbp-t1-touchbar-0.3
rpmbuild --define "_topdir $BUILD_DIR" -ba "$ROOT_DIR/rpm/mbp-t1-touchbar-dkms.spec"
cp "$BUILD_DIR"/RPMS/noarch/*.rpm "$OUT/"
cp "$BUILD_DIR"/SRPMS/*.rpm "$OUT/"
