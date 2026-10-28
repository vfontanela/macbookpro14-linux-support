#!/usr/bin/env bash
# Build the Fedora RPMs in a clean fedora:<release> container (podman or docker).
#   packaging/fedora/build-container.sh [out-dir]
# Env: FEDORA (default 45), SKIP_FPRINT=1 to build only the t1bridge packages.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
fedora=${FEDORA:-45}
out=$(realpath -m "${1:-$root/dist/rpm/fedora-$fedora}")
engine=$(command -v podman || command -v docker) || { echo "need podman or docker" >&2; exit 1; }
mkdir -p "$out"
"$engine" run --rm -e SKIP_FPRINT="${SKIP_FPRINT:-}" \
  -v "$root:/src:ro,Z" -v "$out:/out:Z" "registry.fedoraproject.org/fedora:$fedora" bash -euc '
    dnf -y -q install rpm-build git tar rpmdevtools "dnf-command(builddep)" >/dev/null
    dnf -y -q builddep /src/packaging/fedora/t1bridge.spec >/dev/null
    if [[ -z $SKIP_FPRINT ]]; then
      dnf -y -q builddep libfprint fprintd >/dev/null
    fi
    cp -a /src /build
    RPMBUILD_TOPDIR=/build/rpmbuild bash /build/packaging/fedora/build.sh
    find /build/rpmbuild/RPMS -name "*.rpm" ! -name "*debug*" ! -name "*-tests-*" -exec cp {} /out/ \;
    cd /out && sha256sum ./*.rpm > SHA256SUMS && ls -1'
