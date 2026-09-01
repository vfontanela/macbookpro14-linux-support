# mbp-t1-touchbar-dkms

DKMS package that activates the Touch Bar and ambient light sensor on Intel
MacBook Pro models with the **T1** co-processor.

MacBookPro14,1 has a physical function-key row and no Touch Bar, so this package is not applicable to that model. MacBookPro14,2 is the supported 13-inch 2017 Touch Bar model.

Validated on:

| Model | Distribution | Kernel | Result |
|---|---|---|---|
| MacBookPro14,2 | Fedora 44 | 7.1.10 | Touch Bar working through DKMS |
| MacBookPro14,3 | Ubuntu-based | 7.0 | Working |

MacBookPro13,2 / 13,3 / 14,2 / 14,3 share the same T1 iBridge and should use
this driver. This is for T1 Macs, not T2 Macs.

## Fedora 44

Install the build requirements for the running kernel:

```bash
sudo dnf install git dkms gcc make kernel-devel-$(uname -r) kernel-headers
```

Clone this repository and build the RPM that registers the driver with DKMS:

```bash
git clone https://github.com/vfontanela/macbookpro14-linux-support.git
cd macbookpro14-linux-support/touchbar
sudo dnf install rpm-build
rpmbuild -ba rpm/mbp-t1-touchbar-dkms.spec
sudo dnf install ~/rpmbuild/RPMS/noarch/mbp-t1-touchbar-dkms-*.noarch.rpm
sudo reboot
```

If the RPM is already available from a release or a previous build, install it
directly with `sudo dnf install ./mbp-t1-touchbar-dkms-*.noarch.rpm`.

Verify after reboot:

```bash
dkms status
lsmod | grep -E 'apple_ibridge|apple_ib_tb|apple_ib_als'
journalctl -u mbp-t1-touchbar-bind.service --no-pager
```

The package also installs the USB rebind service and udev rule required when
the generic USB driver claims the iBridge before `apple-ibridge`.

## Ubuntu and Kubuntu

```bash
sudo apt install linux-headers-$(uname -r) dkms
sudo dpkg -i mbp-t1-touchbar-dkms_<version>_all.deb
sudo apt -f install   # only if dpkg reports missing dependencies
sudo reboot
```

## Requirements and troubleshooting

Confirm that the T1 firmware is present:

```bash
lsusb
```

- `05ac:8600 Apple, Inc. iBridge`: firmware is intact.
- `05ac:1281 Apple Mobile Device [Recovery Mode]`: boot macOS once so it
  can restore the T1 firmware, then return to Linux.

If the modules are loaded but the Touch Bar remains blank, check the rebind
service and reboot once after the initial installation.

## Configuration

Edit `/etc/modprobe.d/mbp-t1-touchbar.conf` to change Fn-key mode,
brightness and idle/dim timeouts. Reload the module after changing it:

```bash
sudo modprobe -r apple-ib-tb
sudo modprobe apple-ib-tb
```

## Components

| Module | Purpose |
|---|---|
| `apple-ibridge` | Connects to Apple's T1 iBridge virtual USB hub |
| `apple-ib-tb` | Renders the Touch Bar and handles touch input |
| `apple-ib-als` | Exposes the ambient light sensor through IIO |

The driver is out of tree and based on
[parport0/mbp-t1-touchbar-driver](https://github.com/parport0/mbp-t1-touchbar-driver),
originally written by Ronald Tschalär. See
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for additional diagnostics.
