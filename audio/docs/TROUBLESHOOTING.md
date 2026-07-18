# Troubleshooting

## The core fragility of this driver (read this first)

Unlike a normal out-of-tree module, this one doesn't just compile
against kernel *headers*. Its `PRE_BUILD` step
(`install.cirrus.driver.sh`) downloads the **sound/hda subsystem
source** of a kernel tree matching your exact running kernel version,
patches it, and only then builds against that. Two consequences:

1. **It needs internet access at build time** - not just at install
   time, but every single time DKMS rebuilds it (i.e. after every
   kernel update, automatically, via
   `/etc/kernel/postinst.d/dkms`).
2. **It needs a source package that actually matches your kernel
   version.** On Ubuntu/Debian it looks for
   `/usr/src/linux-source-<version>.tar.bz2`. This works for stock
   distro kernels but generally **does not exist for HWE kernels**
   (Ubuntu's rolling hardware-enablement kernels) or custom/mainline
   PPA kernels - the script explicitly checks and exits with an error
   if it's missing, it does not silently fall back to kernel.org on
   Ubuntu.

If your kernel updates automatically pull in a kernel that has no
matching `linux-source-*` package, the DKMS rebuild **will** fail on
that kernel, exactly as it did before this was packaged - DKMS doesn't
fix that class of problem, it only automates the retry.

## Build fails: `linux kernel source not found in /usr/src`

```
sudo apt install linux-source-<kernel-version>
```

Where `<kernel-version>` is `uname -r` with the `-XX-generic` suffix
stripped (e.g. `7.0.0`, not `7.0.0-27-generic`). If that package
doesn't exist in your repos:

- Check if it's available via `apt search linux-source-` for nearby
  versions.
- As a last resort, the non-Ubuntu code path in
  `install.cirrus.driver.sh` downloads straight from kernel.org
  (`https://cdn.kernel.org/pub/linux/kernel/vX.x/linux-<version>.tar.xz`).
  This only triggers automatically on non-Ubuntu-flavoured distros; on
  Ubuntu you'd need to either fake `/etc/os-release` temporarily or
  manually place `/usr/src/linux-source-<version>.tar.bz2` yourself.

## Build fails with GCC errors (`incompatible-pointer-types`, etc.)

This is exactly what `src/dkms.conf`'s custom `MAKE` line already
works around (`-Wno-error -Wno-incompatible-pointer-types` and
friends). If you still hit compiler errors, check
`/var/lib/dkms/snd_hda_macbookpro/1.0/build/make.log` for the actual
line - it may be a genuinely new incompatibility that needs an
additional `-Wno-*` flag or a real patch, not just a suppressed
warning.

## After a kernel update, DKMS autoinstall failed and blocked the kernel package install

This is the classic upstream issue (davidjo/snd_hda_macbookpro#118).
It happens when `apt upgrade` installs a new kernel, the DKMS post-inst
hook tries to rebuild this module for it, and that build fails (usually
because of the two reasons above) - `apt` then reports the kernel
package itself as failed even though the kernel installed fine.

This is not dangerous (the kernel is installed, only the DKMS module
build failed), but it's noisy. To unblock `apt`:

```bash
sudo dkms status
# find the failed build, e.g. snd_hda_macbookpro/1.0, <new-kernel>: not built
sudo apt install linux-source-<matching-version>    # fix the root cause
sudo dkms install -m snd_hda_macbookpro -v 1.0 -k $(uname -r) --force
sudo apt --fix-broken install
```

## Module builds and installs, but no sound after reboot

1. `lsmod | grep cs8409` - confirm the module is actually loaded.
2. In your desktop's sound settings, set the output to **"Analogue
   Stereo Output"** (not the default/dummy profile).
3. For the internal mic, set input to **"Analogue Stereo Duplex"**.
4. Recorded mic level is very low by design (matches macOS raw level) -
   this needs software gain (e.g. PulseEffects), it's not a driver bug.

## Checking what actually got built

```bash
dkms status
ls -la /lib/modules/$(uname -r)/updates/codecs/cirrus/
```
