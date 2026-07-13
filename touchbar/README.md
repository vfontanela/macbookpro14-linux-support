[README.md](https://github.com/user-attachments/files/29968915/README.md)
# mbp-t1-touchbar-dkms

DKMS package that activates the Touch Bar (and ambient light sensor) on
Intel MacBook Pro models with the **T1** co-processor, running Linux.

Tested on: MacBook Pro 2017 (MacBookPro14,3), kernel 7.0 (Ubuntu-based).
Should also work on MacBookPro13,2 / 13,3 / 14,2 (late 2016 / mid 2017,
13" and 15" Touch Bar models) — these all share the same T1 iBridge.

> **This is for T1, not T2.** If your Mac is 2018 or newer, it has a T2
> chip instead, which is a different device with increasing native
> kernel support since Linux 6.15 (`hid-appletb-kbd`, `hid-appletb-bl`,
> `appletbdrm`). Don't use this package on a T2 machine — see
> [`docs/T1_VS_T2.md`](docs/T1_VS_T2.md) for details.

## What this actually is

Three kernel modules doing the low-level work:

| Module | Purpose |
|---|---|
| `apple-ibridge` | Talks to the iBridge, Apple's virtual USB hub that exposes the Touch Bar, ALS, and other T1 peripherals as HID devices |
| `apple-ib-tb` | Touch Bar driver: renders the on-screen keys, handles touch/tap input, exposes brightness/idle sysfs controls |
| `apple-ib-als` | Ambient light sensor (IIO subsystem) |

These are **not upstream** — there is no in-tree Linux driver for the T1
Touch Bar. The source here is an updated fork, by
[parport0](https://github.com/parport0/mbp-t1-touchbar-driver), of the
original out-of-tree driver written by Ronald Tschalär.

What this repo adds on top of the raw driver source:

- **DKMS packaging** — the module is compiled against *your* running
  kernel's headers when you install the package, and automatically
  rebuilt on every kernel update. No need to manually `make` after
  every `apt upgrade`.
- **Automatic USB rebind** — `apple-ibridge` only registers a HID
  driver, not a full `usb_driver`, so the generic `usb` driver often
  claims the device first and the Touch Bar stays blank even with the
  modules loaded. A helper script + systemd service + udev rule handle
  the unbind/reprobe dance automatically, including after resume from
  suspend (the iBridge re-enumerates on the USB bus at that point).
- A `.deb` you can just `dpkg -i`.

## Requirements

- `dkms` and the `linux-headers` package matching your **running**
  kernel (`uname -r`).
- Your T1 must not be in recovery mode. Check with `lsusb`:
  - `05ac:8600 Apple, Inc. iBridge` → good, firmware is intact.
  - `05ac:1281 Apple Mobile Device [Recovery Mode]` → the T1's
    firmware is missing; boot macOS once to let it restore itself,
    then reboot into Linux.

## Install

```bash
sudo apt install linux-headers-$(uname -r) dkms
sudo dpkg -i mbp-t1-touchbar-dkms_<version>_all.deb
sudo apt -f install   # only if dpkg reports missing deps
```

The post-install script registers the source with DKMS, builds and
installs the module for your current kernel, enables the rebind
service, and reloads udev rules.

## Verify

```bash
dkms status
lsusb -t | grep 05ac:8600
journalctl -u mbp-t1-touchbar-bind.service --no-pager
```

If the Touch Bar is still blank after all of that, a reboot usually
finishes the job on first install.

## Configuration

Edit `/etc/modprobe.d/mbp-t1-touchbar.conf` to change Touch Bar
behavior (Fn-key mode, idle/dim timeouts), then reload the module:

```bash
sudo modprobe -r apple-ib-tb && sudo modprobe apple-ib-tb
```

## Building from source

```bash
git clone <this-repo>
cd mbp-t1-touchbar-dkms
./build.sh            # -> mbp-t1-touchbar-dkms_1.0-2_all.deb
```

## Repo layout

```
src/            kernel module source (apple-ibridge, apple-ib-tb, apple-ib-als) + dkms.conf
scripts/        bind-touchbar.sh - USB unbind/reprobe helper
systemd/        mbp-t1-touchbar-bind.service
udev/           99-mbp-t1-touchbar.rules
modprobe.d/     default module options
modules-load.d/ boot-time module load order
debian/         control, postinst, prerm, postrm, conffiles
docs/           troubleshooting, T1 vs T2 background, changelog
build.sh        assembles pkgroot and builds the .deb
```

## Uninstall

```bash
sudo apt remove mbp-t1-touchbar-dkms      # keep config files
sudo apt purge mbp-t1-touchbar-dkms       # also remove them
```

## Credits / license

- Original T1 Touch Bar driver: Ronald Tschalär.
- Updated fork used as source: [parport0/mbp-t1-touchbar-driver](https://github.com/parport0/mbp-t1-touchbar-driver).
- DKMS packaging, systemd/udev automation: this repo.
- License: GPL-2.0 (see `LICENSE-NOTES.txt`).

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for common
build/runtime issues, and [`docs/CHANGELOG.md`](docs/CHANGELOG.md)
for package history.
