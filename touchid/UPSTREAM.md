# Provenance and licensing

## T1Bridge

Project: https://github.com/standardagents/t1bridge
Pinned tag/commit: `v0.1.12` = `81cbdf81026a16e02f0bea74735c6b029a8ffae2` (2026-09-20).
`build.sh` clones exactly this commit and refuses any other.

T1Bridge contributors wrote the drivers, the broker, the services, the
Touch Bar renderer and the original Arch packaging. Userspace is MIT. The kernel
components keep their own MIT, GPL-2.0-only or GPL-2.0-or-later notices
(upstream `kernel/LICENSE.md`). Renderer asset and dependency notices are in
upstream `THIRD_PARTY_NOTICES.md`, which the packages install.

This repository holds **no T1Bridge source**, only the packaging that is
overlaid on the pinned tree at build time:

| Path here | Overlaid as | Origin |
|---|---|---|
| `fedora/` | `packaging/fedora/` | new: Fedora spec, dracut drop-in, SELinux module, installers |
| `debian/` | `packaging/debian/` | new: container build, maintainer scripts, installer |
| `debian/patches/<release>/t1bridge-driver.patch` | Debian quilt patch | port of upstream `packaging/arch/libfprint-t1bridge/0001-Add-T1Bridge-fingerprint-driver.patch` |
| `docs/pt-BR/{fedora,debian}.md` | `docs/` | new guides (Portuguese) |

Local changes to T1Bridge itself: **none**. The C/Rust sources, kernel
modules, systemd units and udev rules are used unchanged.

## libfprint and fprintd

These are not vendored. Each build downloads the distribution's own source
package and rebuilds it under the same package names, with these patches:

| Distribution | Source package | Patches |
|---|---|---|
| Fedora 45 | `libfprint-1.94.100-1.fc45`, `fprintd-1.94.5-6.fc45` (`dnf download --source`) | upstream Arch patches, unmodified |
| Debian 13 | `libfprint 1:1.94.9-1`, `fprintd 1.94.5-2` (`apt-get source`) | ported driver patch; upstream fprintd patch 0001 |
| Ubuntu 26.04 | `libfprint 1:1.95.1+tod1-0ubuntu2`, `fprintd 1.94.5-4` | ported driver patch (enum value appended to keep the TOD ABI; helper `G_GNUC_INTERNAL`); upstream fprintd patch 0001 |

libfprint is LGPL-2.1-or-later; fprintd is GPL-2.0-or-later. Authorship stays
with their upstreams and distribution maintainers. The ported patches omit the
upstream test-suite additions.

**Corresponding source for published binaries:** a later `apt-get source` or
`dnf download --source` may fetch a newer revision. Each release therefore
attaches the exact distribution source inputs that were used, together with a
T1Bridge source archive.

## Not distributed

No Apple firmware, `FDRData`/calibration, keybag, catacomb or biometric state
is in this repository or in any package. Touch ID imports the Mac's own
`EFI/APPLE/EMBEDDEDOS/FDRData` locally at setup time.
