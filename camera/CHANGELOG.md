# Camera component — 0.7.2.git20260929-1

- Add independent RPM/DEB DKMS support for MacBookPro14,1 PCI camera 14e4:1570.
- Preserve existing firmware; obtain/extract Apple firmware locally only if absent.
- Add one-command setup, scoped PCI driver rebind and camera-specific diagnostics.
- Preserve upstream GPLv2 licenses and record exact upstream revisions.
- Keep MacBookPro14,2 USB/UVC camera and Touch Bar 1.0-3 independent and unchanged.
- Clean builds and DKMS compilation passed on Fedora kernels 7.2.6–7.2.8.
- Previously working hardware confirmed by user; this snapshot's streaming,
  Debian install lifecycle and Secure Boot were not independently repeated.
