#!/bin/bash
# Build every package of this repository into dist/ (or OUTDIR).
#   bash build.sh [-o OUTDIR] [component ...]
# Components: audio wifi-bcm4350 wifi-bcm43602 touchbar camera touchid
# (default: all). Needs podman or docker; everything builds in containers.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=$root/dist
if [[ ${1:-} == -o ]]; then out=$(realpath -m "$2"); shift 2; fi
components=("$@")
[[ ${#components[@]} -gt 0 ]] || components=(audio wifi-bcm4350 wifi-bcm43602 touchbar camera touchid)
engine=$(command -v podman || command -v docker) || { echo "needs podman or docker" >&2; exit 1; }
mkdir -p "$out"

noarch=()
for c in "${components[@]}"; do
  case $c in
    audio|wifi-bcm4350|wifi-bcm43602|touchbar) noarch+=("bash /src/$c/build.sh /out") ;;
    camera) noarch+=("python3 /src/camera/build.py --output /tmp/camera && cp /tmp/camera/*.noarch.rpm /tmp/camera/*.deb /out/") ;;
    touchid) ;;
    *) echo "unknown component: $c" >&2; exit 1 ;;
  esac
done

# DKMS and firmware packages are architecture-independent: one Fedora
# container builds both the .rpm and the .deb of each.
if [[ ${#noarch[@]} -gt 0 ]]; then
  cmds=$(printf '%s && ' "${noarch[@]}")
  "$engine" run --rm -v "$root:/src:ro,Z" -v "$out:/out:Z" registry.fedoraproject.org/fedora:45 bash -euc "
    dnf -q -y install rpm-build dpkg git-core python3 tar gzip xz >/dev/null
    $cmds true"
fi

# Touch ID replaces the distribution's libfprint/fprintd, so it is built per
# distribution and shipped as one archive per distribution.
if [[ " ${components[*]} " == *" touchid "* ]]; then
  bash "$root/touchid/build.sh" "$out/touchid"
  for dir in "$out"/touchid/rpm/* "$out"/touchid/deb/*; do
    distro=${dir##*/} bundle=$out/touchid/t1bridge-0.1.12-${dir##*/}
    mkdir -p "$bundle"
    cp -a "$dir" "$bundle/"
    cp "$root/touchid/README.md" "$bundle/"
    tar -C "$out/touchid" -czf "$bundle-packages.tar.gz" --owner=0 --group=0 "${bundle##*/}"
    mv "$bundle-packages.tar.gz" "$out/"
  done
  rm -rf "$out/touchid"
fi

(cd "$out" && sha256sum -- *.rpm *.deb *.tar.gz 2>/dev/null > SHA256SUMS)
echo "Packages in $out:"
ls -1 "$out"
