#!/usr/bin/env bash
# Build the Fedora RPMs for T1Bridge as an unprivileged user:
#   t1bridge, t1bridge-dkms, t1bridge-selinux  (from this checkout)
#   libfprint, fprintd                         (Fedora's own SRPMs + T1Bridge patches)
# Build dependencies: see "sudo dnf builddep" in docs/fedora.md.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
arch_pkg="$root/packaging/arch"
top=${RPMBUILD_TOPDIR:-$HOME/rpmbuild}
version=$(sed -n 's/^Version:[[:space:]]*//p' "$here/t1bridge.spec")

mkdir -p "$top"/{SOURCES,SPECS,SRPMS,RPMS}

# --- t1bridge -----------------------------------------------------------------
# In a Git checkout: tracked plus new, non-ignored files. In an extracted source
# archive: every file except build output.
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  (cd "$root" && git ls-files -co --exclude-standard -z |
    tar --null -T - --transform "s,^,t1bridge-$version/," -czf "$top/SOURCES/t1bridge-$version.tar.gz")
else
  tar -C "$root" --exclude=./target --exclude=./dist --transform "s,^\.,t1bridge-$version," \
    -czf "$top/SOURCES/t1bridge-$version.tar.gz" .
fi
(cd "$root" && cargo fetch --locked)
# install.sh accepts one version per package: drop older t1bridge RPMs from
# this build tree (only those this script produces).
find "$top/RPMS" -name 't1bridge-*.rpm' -delete
rpmbuild -bb --define "_topdir $top" "$here/t1bridge.spec"

# SKIP_FPRINT=1: only T1Bridge (libfprint/fprintd unchanged since the last release).
[[ -z ${SKIP_FPRINT:-} ]] || exit 0

# --- libfprint / fprintd ---------------------------------------------------------
# Rebuild Fedora's packages under their own names so every Fedora dependent
# (GNOME, pam_fprintd, ...) keeps working. Release gets a ".t1bridge" suffix.
# Skipped when this Fedora release's pair is already built; FORCE_FPRINT=1 rebuilds.
fedora_nvr() { dnf repoquery --available --latest-limit 1 --qf '%{version}-%{release}' "$1" 2>/dev/null | sed 's/\.fc/.t1bridge.fc/'; }
if [[ -z ${FORCE_FPRINT:-} ]] &&
   ls "$top"/RPMS/x86_64/libfprint-"$(fedora_nvr libfprint)".x86_64.rpm \
      "$top"/RPMS/x86_64/fprintd-"$(fedora_nvr fprintd)".x86_64.rpm >/dev/null 2>&1; then
  echo "libfprint/fprintd already built for this Fedora release; skipping"
  exit 0
fi
cd "$top/SRPMS"
dnf download --source libfprint fprintd
for srpm in libfprint-*.src.rpm fprintd-*.src.rpm; do
  rpm -i --define "_topdir $top" "$srpm"
done

patch_spec() { # spec, patch-dir
  local spec=$1 dir=$2 n=9001 lines="" p
  grep -q '^Patch9001:' "$spec" && return 0
  for p in "$dir"/*.patch; do
    cp "$p" "$top/SOURCES/"
    lines+="Patch$n: $(basename "$p")"$'\n'
    n=$((n + 1))
  done
  # %autosetup -S git applies every PatchN in order.
  awk -v add="$lines" '{ print } /^Source0:/ && !done { printf "%s", add; done = 1 }' \
    "$spec" > "$spec.new"
  mv "$spec.new" "$spec"
  sed -i 's/^\(Release:[[:space:]]*\)%autorelease$/\1%autorelease -e t1bridge/' "$spec"
}

patch_spec "$top/SPECS/libfprint.spec" "$arch_pkg/libfprint-t1bridge"
patch_spec "$top/SPECS/fprintd.spec" "$arch_pkg/fprintd-t1bridge"

rpmbuild -bb --define "_topdir $top" "$top/SPECS/libfprint.spec"
rpmbuild -bb --define "_topdir $top" "$top/SPECS/fprintd.spec"

echo
echo "RPMs:"
find "$top/RPMS" -name '*.rpm' \( -name 't1bridge*' -o -name '*t1bridge*' \) -newer "$here/t1bridge.spec" -print
