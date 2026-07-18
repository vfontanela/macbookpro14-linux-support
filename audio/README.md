# mbp-cirrus-audio-dkms

DKMS package for internal speaker/microphone audio (Cirrus Logic
CS8409 HDA codec + MAX98706/SSM3515 amps) on 2017+ MacBook Pro / iMac
Pro models running Linux.

This wraps [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
as a proper DKMS source package, so the module is rebuilt
**automatically on every kernel update**, the same way
[`mbp-t1-touchbar-dkms`](../mbp-t1-touchbar-dkms-repo) handles the
Touch Bar - no more manually re-running `install.cirrus.driver.sh` +
`dkms.sh` after every `apt upgrade`.

## Read this before installing: this driver is not "fire and forget"

Unlike a typical kernel module, this one's build step downloads and
patches the **sound/hda subsystem source of your exact running
kernel**, not just headers. That means:

- It needs **internet access** every time it (re)builds - including
  automatically, during a kernel update.
- It needs a `linux-source-<your-exact-kernel-version>` package to
  exist and be installed - this generally works for stock distro
  kernels, but **not for Ubuntu HWE kernels** or other kernels without
  a matching source package.

If a kernel update pulls in a kernel version with no matching
`linux-source` package available, the automatic rebuild will fail on
that kernel and you'll be back to manual troubleshooting - DKMS
automates the *retry*, it doesn't remove this fundamental constraint.
See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Risk mitigation: what's actually vendored vs. what still needs the network

Two separate risks were raised about this package, and they have very
different answers:

**"What if davidjo's GitHub repo disappears?"** - Already solved. The
entire upstream source tree (patches, Makefiles, install scripts) is
vendored into `src/` in *this* repo. Nothing is fetched from
`github.com/davidjo/...` at install or build time.

**"What if the kernel-source download breaks / becomes unavailable?"**
- Reduced, but not eliminated, and can't be fully eliminated.
`install.cirrus.driver.sh` in this package includes a local-cache
patch (clearly marked `local cache patch (not upstream)` in the file,
to keep the diff from upstream obvious): it saves the downloaded +
patched `sound/hda` source tree to
`/var/cache/mbp-cirrus-audio-dkms/hda-src/`, keyed by kernel version.
Since Ubuntu kernel ABI bumps (`7.0.0-27-generic` -> `7.0.0-29-generic`)
share the same underlying `kernel_version` ("7.0.0"), **routine kernel
updates reuse the cache and need zero network access**. Only a
genuinely new upstream kernel version (a real `7.0` -> `7.1` bump, not
just an ABI/security respin) still triggers one fresh download - at
that point there's no way around it, because that kernel's patched
source doesn't exist anywhere yet, including in this repo, until
someone runs the build against it once.

What this means in practice: the first install, and the first build
after each real kernel version bump, need internet + a matching
`linux-source` package. Every kernel update in between (which is most
of them) is fully offline once that cache is populated.

## Install

```bash
sudo apt install dkms build-essential patch wget \
                  linux-headers-$(uname -r) \
                  linux-source-$(uname -r | cut -d- -f1)
sudo dpkg -i mbp-cirrus-audio-dkms_1.0-1_all.deb
sudo apt -f install   # only if dpkg reports missing deps
sudo reboot
```

`postinst` checks for the matching `linux-source-*` package before
attempting the build and tells you exactly what to install if it's
missing, instead of failing with a confusing error buried in DKMS logs.

## Verify

```bash
dkms status
lsmod | grep cs8409
```

In your sound settings, set output to **Analogue Stereo Output**
(or **Analogue Stereo Duplex** if you also want the internal mic).

## What's different from the upstream repo

- `src/dkms.conf` replaces the upstream default with the fix from
  [upstream issue #164](https://github.com/davidjo/snd_hda_macbookpro/issues/164):
  a custom `MAKE` command with `CFLAGS_MODULE` overrides
  (`-Wno-error`, `-Wno-incompatible-pointer-types`, etc.) required to
  build on GCC 14+ / kernel 6.17+, which also covers kernel 7.x - the
  script's own `major_version -ge 7` branch already applies the same
  Cirrus codec patches used for 6.17+.
- `debian/postinst` proactively checks for the matching
  `linux-source-<version>` package and gives you the exact `apt`
  command if it's missing, rather than letting the build fail deep
  inside `install.cirrus.driver.sh`.
- Packaged as a `.deb` with standard DKMS registration, so kernel
  updates trigger an automatic rebuild via
  `/etc/kernel/postinst.d/dkms` - same mechanism as any other DKMS
  package (e.g. VirtualBox's kernel modules).

Everything else - the actual patches, Makefiles, and codec fixups -
is upstream's unmodified work.

## Repo layout

```
src/            full upstream source tree (patches, makefiles, install
                scripts) plus the fixed dkms.conf
debian/         control, postinst, prerm, postrm
docs/           troubleshooting, changelog
build.sh        assembles pkgroot and builds the .deb
```

## Uninstall

```bash
sudo apt remove mbp-cirrus-audio-dkms
```

## Credits / license

- Driver, patches, Cirrus codec support: [davidjo](https://github.com/davidjo/snd_hda_macbookpro)
  and contributors.
- `dkms.conf` GCC14+/kernel 6.17+ fix: [fabioabranquetat, issue #164](https://github.com/davidjo/snd_hda_macbookpro/issues/164)
  (based on a tutorial originally published on Medium).
- DKMS `.deb` packaging: this repo.
- License: GPL-2.0 (see `src/LICENSE`).
