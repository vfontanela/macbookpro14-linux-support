#!/bin/bash
# Build the Touch ID (T1Bridge) RPM/DEB packages in clean distribution
# containers (podman or docker); no installation.
#   bash touchid/build.sh /absolute/output/path [fedora-45|debian-13|ubuntu-26.04 ...]
# Env: SKIP_FPRINT=1 builds only the t1bridge packages (libfprint/fprintd
#      unchanged); MAINTAINER="Name <email>" for the .deb Maintainer field.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=$(realpath -m "${1:-$here/../dist/touchid}")
shift || true
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || targets=(fedora-45 debian-13 ubuntu-26.04)

# Pinned upstream: see UPSTREAM.md.
upstream=https://github.com/standardagents/t1bridge.git
tag=v0.1.12
commit=81cbdf81026a16e02f0bea74735c6b029a8ffae2

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone -q --depth 1 --branch "$tag" "$upstream" "$work/t1bridge"
[[ $(git -C "$work/t1bridge" rev-parse HEAD) == "$commit" ]] ||
  { echo "upstream $tag is not the pinned commit $commit" >&2; exit 1; }

# Overlay this component's packaging onto the upstream tree, at the paths the
# build scripts expect (packaging/<distro>, docs/<guide>.md).
cp -a "$here/fedora" "$work/t1bridge/packaging/fedora"
cp -a "$here/debian" "$work/t1bridge/packaging/debian"
cp "$here/docs/pt-BR/fedora.md" "$here/docs/pt-BR/debian.md" "$work/t1bridge/docs/"

mkdir -p "$out"
for target in "${targets[@]}"; do
  case $target in
    fedora-*)
      FEDORA=${target#fedora-} bash "$work/t1bridge/packaging/fedora/build-container.sh" "$out/rpm/$target"
      install -m 755 "$here/fedora/install.sh" "$out/rpm/$target/" ;;
    debian-*|ubuntu-*)
      bash "$work/t1bridge/packaging/debian/build.sh" "$out/deb" "$target" ;;
    *) echo "unknown target: $target" >&2; exit 1 ;;
  esac
done
echo "Touch ID packages in $out"
