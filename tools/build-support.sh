#!/bin/bash
# Build independent Touch Bar and camera packages; no installation or firmware.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=$(realpath -m "${1:-$root/dist}")
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$out"
cp -a "$root/touchbar" "$stage/"
bash "$stage/touchbar/build.sh"
cp "$stage/touchbar/mbp-t1-touchbar-dkms_1.0-3_all.deb" "$out/"
bash "$stage/touchbar/build-rpm.sh" "$out"
python3 "$root/camera/build.py" --output "$out"
(cd "$out" && sha256sum -- *.rpm *.deb > SHA256SUMS)
