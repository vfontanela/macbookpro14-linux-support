#!/bin/bash
# Build mbp-t1-touchbar-dkms (.rpm and .deb).
#   bash touchbar/build.sh OUTDIR        needs rpmbuild, dpkg-deb
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=$(realpath -m "$1")
version=1.0 release=4 modname=mbp-t1-touchbar modver=0.3
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

# RPM
mkdir -p "$work/rpm"/{BUILD,RPMS,SOURCES,SPECS,SRPMS} "$work/$modname-$modver"
cp -a "$here"/{src,scripts,systemd,udev,modprobe.d,modules-load.d,README.md,CHANGELOG.md,LICENSE} "$work/$modname-$modver/"
tar -czf "$work/rpm/SOURCES/$modname-$modver.tar.gz" -C "$work" "$modname-$modver"
rpmbuild -bb --quiet --define "_topdir $work/rpm" --define "dist %{nil}" "$here/rpm/$modname-dkms.spec"
cp "$work"/rpm/RPMS/noarch/*.rpm "$out/"

# DEB
deb=$work/deb
src=$deb/usr/src/$modname-$modver
install -d "$deb/DEBIAN" "$src/linux" "$deb/etc/modprobe.d" "$deb/etc/modules-load.d" \
  "$deb/etc/udev/rules.d" "$deb/lib/systemd/system" "$deb/usr/libexec/$modname" \
  "$deb/usr/share/doc/$modname-dkms"
install -m 644 "$here"/src/{apple-ibridge.c,apple-ib-tb.c,apple-ib-als.c,Makefile,dkms.conf} "$src/"
install -m 644 "$here/src/linux/apple-ibridge.h" "$src/linux/"
install -m 755 "$here/scripts/bind-touchbar.sh" "$deb/usr/libexec/$modname/"
install -m 644 "$here/systemd/$modname-bind.service" "$deb/lib/systemd/system/"
install -m 644 "$here/udev/99-$modname.rules" "$deb/etc/udev/rules.d/"
install -m 644 "$here/modprobe.d/$modname.conf" "$deb/etc/modprobe.d/"
install -m 644 "$here/modules-load.d/$modname.conf" "$deb/etc/modules-load.d/"
install -m 644 "$here/README.md" "$here/CHANGELOG.md" "$deb/usr/share/doc/$modname-dkms/"
install -m 644 "$here/LICENSE" "$deb/usr/share/doc/$modname-dkms/copyright"
install -m 644 "$here/debian/control" "$here/debian/conffiles" "$deb/DEBIAN/"
install -m 755 "$here"/debian/{postinst,prerm,postrm} "$deb/DEBIAN/"
sed -i "s/^Version: .*/Version: $version-$release/" "$deb/DEBIAN/control"
dpkg-deb --root-owner-group -Zxz --build "$deb" "$out/$modname-dkms_$version-${release}_all.deb" >/dev/null
