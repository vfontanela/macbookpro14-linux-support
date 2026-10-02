#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
source /usr/libexec/macbook-facetimehd/hardware.sh
# Recheck: PCI hardware may have disappeared since package pre-install.
facetimehd_require_hardware || exit 0
name=facetimehd
version=0.7.2.git20260929
kernel=$(uname -r)
[[ -d "/lib/modules/$kernel/build" ]] || {
    echo "Matching kernel headers missing for $kernel. Install them, then run:" >&2
    echo 'sudo /usr/libexec/macbook-facetimehd/install-dkms.sh' >&2
    exit 1
}
if ! dkms status -m "$name" -v "$version" | grep -q .; then
    dkms add -m "$name" -v "$version"
fi
dkms build -m "$name" -v "$version" -k "$kernel"
dkms install -m "$name" -v "$version" -k "$kernel"
echo 'DKMS installed. Firmware is not included or downloaded during package installation.'
echo 'Next: sudo macbook-facetimehd setup (keeps existing firmware)'
