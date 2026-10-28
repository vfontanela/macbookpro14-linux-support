#!/usr/bin/env bash
# Runs inside a Debian/Ubuntu container started by build.sh.
#   /src  read-only T1Bridge checkout
#   /out  directory that receives the .deb files
# Env: TARGET (debian-13 | ubuntu-26.04), MAINTAINER
set -euo pipefail

: "${TARGET:?}" "${MAINTAINER:?}"
export DEBIAN_FRONTEND=noninteractive DEBEMAIL="$MAINTAINER" DEBFULLNAME="T1Bridge packaging"
version=$(sed -n 's/^Version:[[:space:]]*//p' /src/packaging/fedora/t1bridge.spec)
deb_version="$version-${DEB_REVISION:-2}~${TARGET//-/}"
pkgdir=/src/packaging/debian
work=/build
mkdir -p "$work" /out

# --- toolchain ------------------------------------------------------------------
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/*.sources
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  build-essential devscripts dpkg-dev equivs fakeroot quilt git ca-certificates \
  rustup pkg-config libcurl4-openssl-dev libarchive-dev libssl-dev liblzma-dev \
  libudev-dev libsystemd-dev >/dev/null
[[ -n ${SKIP_FPRINT:-} ]] || apt-get build-dep -y -qq libfprint fprintd >/dev/null
# Debian 13 ships rustc 1.85; T1Bridge needs >= 1.88 (edition 2024).
rustup -q toolchain install stable --profile minimal
rustup -q default stable

depends_of() { # binaries... -> "pkg1, pkg2" (shared-library packages, this release)
  # Direct DT_NEEDED only; resolve /lib -> /usr/lib (usrmerge) for dpkg -S.
  readelf -d "$@" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort -u |
    while read -r so; do ldconfig -p | awk -v so="$so" '$1 == so && /x86-64/ {print $NF; exit}'; done |
    xargs -r readlink -f | sort -u |
    { xargs -r dpkg -S 2>/dev/null || true; } | cut -d: -f1 | sort -u | paste -sd, | sed 's/,/, /g'
}

# --- t1bridge ---------------------------------------------------------------------
cp -a /src "$work/t1bridge-src"
cd "$work/t1bridge-src"
for spec in \
    "t1-touchbar-hw t1-touchbar-hw --features service" \
    "t1-touchbar t1-touchbar" \
    "t1-daemons t1-xart-storage" \
    "t1-daemons t1-ncm-ready" \
    "t1-daemons t1-keybag-relay --features keybag-relay-service" \
    "t1-daemons t1-touchid-auth --features auth-broker-service" \
    "t1-daemons t1-touchid" \
    "t1-daemons t1-legacy-recovery --features legacy-recovery" \
    "t1-import t1bridge"; do
  set -- $spec
  pkg=$1 bin=$2; shift 2
  cargo build --locked --release -p "$pkg" --bin "$bin" "$@"
done

root=$work/stage/t1bridge
lib=$root/usr/lib/t1bridge
for b in t1-touchbar-hw t1-touchbar t1-xart-storage t1-ncm-ready t1-keybag-relay t1-touchid-auth; do
  install -Dm755 target/release/$b $lib/$b
done
install -Dm750 target/release/t1-legacy-recovery $lib/t1-legacy-recovery
install -Dm755 target/release/t1-touchid $root/usr/bin/t1-touchid
install -Dm755 target/release/t1bridge $root/usr/bin/t1bridge
for u in t1-touchbar-hw.service t1-touchbar-hw.socket t1-xart-storage@.service \
         t1-ncm-ready@.service t1bridge-keybag.service t1-touchid-auth.service \
         t1-touchid-auth.socket t1bridge-fingerprint.socket t1bridge-import.service; do
  install -Dm644 systemd/$u $root/usr/lib/systemd/system/$u
done
install -Dm644 systemd/user/t1-touchbar.service $root/usr/lib/systemd/user/t1-touchbar.service
install -Dm644 systemd/80-t1bridge.preset $root/usr/lib/systemd/system-preset/80-t1bridge.preset
install -Dm644 systemd/user/80-t1bridge.preset $root/usr/lib/systemd/user-preset/80-t1bridge.preset
install -Dm644 systemd/t1bridge.sysusers $root/usr/lib/sysusers.d/t1bridge.conf
install -Dm644 systemd/t1bridge.conf $root/usr/lib/tmpfiles.d/t1bridge.conf
install -Dm644 systemd/50-t1bridge-ncm.link $root/usr/lib/systemd/network/50-t1bridge-ncm.link
install -Dm644 systemd/99-zz-t1bridge-touchbar.rules $root/usr/lib/udev/rules.d/99-zz-t1bridge-touchbar.rules
install -Dm644 systemd/90-t1bridge-xart.rules $root/usr/lib/udev/rules.d/90-t1bridge-xart.rules
# MIT for T1Bridge; renderer assets/crates carry their own notices.
install -Dm644 LICENSE $root/usr/share/doc/t1bridge/copyright
install -Dm644 THIRD_PARTY_NOTICES.md $root/usr/share/doc/t1bridge/THIRD_PARTY_NOTICES.md
install -Dm644 docs/debian.md $root/usr/share/doc/t1bridge/debian.md
install -Dm644 docs/touch-id.md $root/usr/share/doc/t1bridge/touch-id.md

install -d $root/DEBIAN
cp $pkgdir/t1bridge/{postinst,prerm,postrm,triggers} $root/DEBIAN/
chmod 755 $root/DEBIAN/{postinst,prerm,postrm}
shlibs=$(depends_of target/release/t1bridge target/release/t1-touchid-auth target/release/t1-touchbar-hw)
[[ -n $shlibs ]] || { echo "could not resolve shared-library packages" >&2; exit 1; }
cat > $root/DEBIAN/control <<EOF
Package: t1bridge
Version: $deb_version
Architecture: amd64
Maintainer: $MAINTAINER
Depends: $shlibs, systemd (>= 256), iio-sensor-proxy, t1bridge-dkms (= $deb_version)
Recommends: fprintd, libpam-fprintd
Section: admin
Priority: optional
Homepage: https://github.com/standardagents/t1bridge
Description: Apple T1 iBridge services (Touch ID and Touch Bar)
 Services for the Apple T1 chip of the 2016/2017 MacBook Pro with Touch Bar:
 USB configuration selection, private NCM link, xART storage, Secure Enclave
 keybag relay, Touch ID broker for libfprint/fprintd and Touch Bar renderer.
EOF

# --- t1bridge-dkms -------------------------------------------------------------------
root=$work/stage/t1bridge-dkms
dkms=$root/usr/src/t1bridge-dkms-$version
install -d $dkms/kernel/{t1-cfgsel,appletbdrm-t1,apple-t1-ncm,uvcvideo-t1,dkms}
install -m644 kernel/t1-cfgsel/{Makefile,t1_cfgsel.c,t1_recovery_reset.h} $dkms/kernel/t1-cfgsel/
install -m644 kernel/appletbdrm-t1/{Makefile,appletbdrm.c,appletbdrm_resume.h,appletbdrm_protocol.h} $dkms/kernel/appletbdrm-t1/
install -m644 kernel/apple-t1-ncm/{Makefile,apple_t1_ncm.c} $dkms/kernel/apple-t1-ncm/
install -m644 kernel/uvcvideo-t1/{Makefile,uvc_*.c,uvc_*.h,uvcvideo.h} $dkms/kernel/uvcvideo-t1/
install -m644 kernel/dkms/Makefile $dkms/kernel/dkms/Makefile
sed "s/^PACKAGE_VERSION=.*/PACKAGE_VERSION=\"$version\"/" kernel/dkms/dkms.conf > $dkms/dkms.conf
install -Dm644 packaging/arch/t1bridge-dkms/t1bridge.modules-load.conf $root/usr/lib/modules-load.d/t1bridge.conf
install -Dm644 packaging/arch/t1bridge-dkms/t1bridge.modprobe.conf $root/usr/lib/modprobe.d/t1bridge.conf
# Load the selector before the iBridge enumerates, for both initramfs generators.
install -Dm644 packaging/fedora/90-t1bridge.dracut.conf $root/usr/lib/dracut/dracut.conf.d/90-t1bridge.conf
install -Dm644 /dev/stdin $root/usr/share/initramfs-tools/modules.d/t1bridge <<<'t1_cfgsel'
install -Dm644 LICENSE $root/usr/share/doc/t1bridge-dkms/copyright
cat kernel/LICENSE.md >> $root/usr/share/doc/t1bridge-dkms/copyright
install -Dm644 LICENSES/GPL-2.0-only.txt $root/usr/share/doc/t1bridge-dkms/GPL-2.0-only.txt
install -d $root/DEBIAN
for s in postinst prerm postrm; do
  sed "s/@VERSION@/$version/" $pkgdir/t1bridge-dkms/$s > $root/DEBIAN/$s
  chmod 755 $root/DEBIAN/$s
done
cat > $root/DEBIAN/control <<EOF
Package: t1bridge-dkms
Version: $deb_version
Architecture: all
Maintainer: $MAINTAINER
Depends: dkms, kmod
Section: kernel
Priority: optional
Homepage: https://github.com/standardagents/t1bridge
Description: Apple T1 iBridge kernel modules (DKMS)
 t1_cfgsel (USB configuration selector), apple_t1_ncm (private host-T1
 network), the T1 appletbdrm Touch Bar display driver and a patched uvcvideo.
EOF

mkdir -p /out/$TARGET
rm -f /out/$TARGET/t1bridge_*.deb /out/$TARGET/t1bridge-dkms_*.deb
for p in t1bridge t1bridge-dkms; do
  arch=$(sed -n 's/^Architecture: //p' "$work/stage/$p/DEBIAN/control")
  dpkg-deb --root-owner-group -Zxz --build "$work/stage/$p" "/out/$TARGET/${p}_${deb_version}_${arch}.deb"
done

# --- libfprint / fprintd ------------------------------------------------------------
# Rebuild this release's own source packages with the T1Bridge patches, keeping
# every binary package name so GNOME, pam-auth-update, etc. stay satisfied.
rebuild() { # source-package patch-file
  local src=$1 patch=$2
  mkdir -p "$work/$src" && cd "$work/$src"
  apt-get source -qq "$src"
  cd "$(find . -maxdepth 1 -mindepth 1 -type d -name "$src-*" | head -1)"
  mkdir -p debian/patches
  cp "$patch" debian/patches/t1bridge.patch
  echo t1bridge.patch >> debian/patches/series
  QUILT_PATCHES=debian/patches quilt push -a -q
  dch --local +t1bridge --distribution UNRELEASED "Add the T1Bridge Apple Touch ID support."
  DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -b -j"$(nproc)"
  cd ..
  cp ./*.deb /out/$TARGET/
}
# SKIP_FPRINT=1 rebuilds only T1Bridge: re-running dpkg-buildpackage on an
# unchanged libfprint/fprintd would publish different bytes under the same version.
if [[ -z ${SKIP_FPRINT:-} ]]; then
  rebuild libfprint "$pkgdir/patches/$TARGET/t1bridge-driver.patch"
  rebuild fprintd /src/packaging/arch/fprintd-t1bridge/0001-Honor-driver-native-duplicate-detection.patch
fi

# Mode 755 even when this checkout lost the executable bit (web upload).
install -m 755 $pkgdir/install.sh /out/$TARGET/
( cd /out/$TARGET && sha256sum ./*.deb > SHA256SUMS )
echo "DEBS OK: $TARGET"
ls -1 /out/$TARGET
