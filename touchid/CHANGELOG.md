# Changelog

## T1Bridge 0.1.12 port, preview.2 — Fedora `0.1.12-4`, Debian/Ubuntu `0.1.12-2`

Addresses the packaging findings of the preview.1 review. Only the
`t1bridge`, `t1bridge-dkms` and `t1bridge-selinux` packages change. The
`libfprint`/`fprintd` packages are byte-identical to preview.1.

- Installers: dnf/apt show the transaction and ask (no `-y`). They verify
  the model, distribution release, architecture, `SHA256SUMS` and one version
  per package. Locks are verified and recorded in `/var/lib/t1bridge-port/`.
  The installers report the PAM state but no longer imply that it is enabled.
- usbmuxd mask: marker line, so an administrator's own
  `/etc/udev/rules.d/39-usbmuxd.rules` is never replaced or removed. The
  preview.1 unmarked copy is recognised and migrated. No longer `%ghost` on
  Fedora, where rpm erased it on upgrade, and regenerated in `%posttrans`.
- DKMS/initramfs: failures are reported instead of ignored. The running
  kernel's initramfs is checked for `t1_cfgsel`. Debian no longer removes the
  DKMS tree on upgrade.
- Debian packages: `THIRD_PARTY_NOTICES.md` and the GPL-2.0 text are
  installed. The maintainer field is set.
- Builds: Fedora RPMs are also built in a clean container, and building from a
  source archive (not a Git checkout) works.
- Docs: SELinux scope is stated as `unconfined_service_t`. Removal commands
  cover every rebuilt subpackage and only the locks the installer added. The
  PAM test matrix includes service-down and cancellation.

Tested in containers: preview.1 to preview.2 upgrade (Fedora `-3`→`-4`,
Debian `-1`→`-2`), administrator-file preservation, removal, the documented
Debian restore, and failure reporting. On hardware (MacBookPro14,2, Fedora 45):
upgrade from `-3`, mask kept, iBridge in configuration 2 after the reboot,
Touch Bar and sudo with the fingerprint working.

## preview.1 — Fedora `0.1.12-3`, Debian/Ubuntu `0.1.12-1`

First Fedora 45, Debian 13 and Ubuntu 26.04 packages. End-to-end hardware test
on MacBookPro14,2 / Fedora 45.
