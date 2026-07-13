# Changelog

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
