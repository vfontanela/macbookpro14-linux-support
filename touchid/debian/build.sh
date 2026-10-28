#!/usr/bin/env bash
# Build the Debian/Ubuntu .deb files in containers (podman or docker), one per
# target release, so each links against that release's own libraries.
#   packaging/debian/build.sh [out-dir] [target...]
# Targets: debian-13 ubuntu-26.04 (default: both)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=$(realpath -m "${1:-$root/dist/deb}")
shift || true
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || targets=(debian-13 ubuntu-26.04)
maintainer=${MAINTAINER:-"T1Bridge packaging <$(git -C "$root" config user.email || echo root@localhost)>"}
engine=$(command -v podman || command -v docker) || { echo "need podman or docker" >&2; exit 1; }

image_for() {
  case $1 in
    debian-13) echo docker.io/library/debian:trixie ;;
    ubuntu-26.04) echo docker.io/library/ubuntu:26.04 ;;
    *) echo "unknown target: $1" >&2; return 1 ;;
  esac
}

mkdir -p "$out"
for target in "${targets[@]}"; do
  image=$(image_for "$target")
  [[ -n ${SKIP_FPRINT:-} ]] || rm -rf "${out:?}/$target"
  echo "=== $target ($image)"
  "$engine" run --rm \
    -e TARGET="$target" -e MAINTAINER="$maintainer" \
    -e SKIP_FPRINT="${SKIP_FPRINT:-}" -e DEB_REVISION="${DEB_REVISION:-}" \
    -v "$root:/src:ro,Z" -v "$out:/out:Z" \
    "$image" bash /src/packaging/debian/build-in-container.sh
done
echo "DEBs em $out"
