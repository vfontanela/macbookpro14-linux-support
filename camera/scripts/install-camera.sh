#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Convenience installer from this checkout. It rejects unsupported hardware
# before calling the package manager (the RPM/DEB also has a pre-install guard).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/hardware.sh"
facetimehd_require_hardware
[[ $# == 1 && -f "$1" ]] || { echo "Usage: sudo $0 /path/to/camera-package.rpm-or.deb" >&2; exit 2; }
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
package=$(realpath "$1")
source /etc/os-release
case " $ID ${ID_LIKE:-} " in
    *fedora*|*rhel*) [[ "$package" == *.rpm ]] || exit 2; dnf install "$package" ;;
    *debian*|*ubuntu*) [[ "$package" == *.deb ]] || exit 2; apt-get install "$package" ;;
    *) echo "Unsupported packaging family: $ID" >&2; exit 2 ;;
esac

# Finish the explicit camera installation with one command; keep existing firmware.
macbook-facetimehd setup
