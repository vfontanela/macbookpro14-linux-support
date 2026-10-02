# Changelog

## 1.0-3 — 2026-10-01

- Correct ExecStart to `/usr/libexec/mbp-t1-touchbar/bind-touchbar.sh` and install the DEB script there too.
- Dynamically discover 05ac:8600 BUSID, reprobe USB, and rebind its :1.3 physical HID to apple-ibridge-hid and virtual 1D6B:0301 HID to apple-ib-touchbar. This handles hid-sensor-hub claiming either layer without a global blacklist.
- Verify driver ownership and all three Touch Bar controls on a HID under the same iBridge. Preserve recovery mode and dynamic HID IDs.
- Remove the multi-user.target ordering cycle and RemainAfterExit so subsequent USB appearances can activate the service again.
- Add sysfs-fixture regression checks and a standalone RPM build helper. DKMS source version remains 0.3 because driver C sources are unchanged.
- The manual two-layer fix worked on Fedora 44 / kernel 7.2.8. Clean package installation and reboot/resume remain unverified.

## 1.0-2

- Fixed `dkms.conf`: removed a custom `MAKE[0]` override that broke
  the module Makefile's kbuild-mode branch, causing
  `make: *** Sem alvo. Pare.` (`No targets. Stop.`) on every build.
  DKMS's default invocation now handles it correctly.
- Removed deprecated `REMAKE_INITRD` directive.
- Confirmed working on kernel 7.0.0-27-generic.

## 1.0-1

- Initial package: DKMS packaging of `parport0/mbp-t1-touchbar-driver`
  (apple-ibridge, apple-ib-tb, apple-ib-als) plus systemd/udev
  automation for the USB unbind/reprobe dance.
- Known issue: DKMS build fails on all kernels due to the `MAKE[0]`
  bug above.
