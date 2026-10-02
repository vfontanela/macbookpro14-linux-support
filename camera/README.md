# FaceTime HD PCIe camera — separate DKMS component

This component packages [patjak/facetimehd](https://github.com/patjak/facetimehd)
for **Broadcom PCIe camera ID `14e4:1570`**. It is independent of `touchbar/`,
`audio/` and `wifi/`; installing it does not install or alter those components.
No metapackage forces the camera onto every MacBook: some use a different camera.

## Hardware and known results

| Hardware | Support route / evidence |
|---|---|
| Intel MacBook with PCI `14e4:1570` | `facetimehd`; install only after detection below |
| MacBookPro14,1 (A1708, no Touch Bar), Fedora 44 | User previously obtained `/dev/video0` and `Apple Facetime HD (PCI:0000:03:00.0)`; model confirmed by the user; previously working with facetimehd. Exact driver/firmware revisions were not recorded. |
| MacBookPro14,2 in this development session | USB iBridge FaceTime HD through `uvcvideo`, already exposes video nodes; **do not install this PCIe package** |
| MacBook Pro 13-inch Late 2013 | Listed as working by the upstream wiki; not tested by this project |
| USB/UVC cameras or T2/newer Macs without `14e4:1570` | This package is not applicable. Use their existing camera support. |

A model name or `/dev/video0` alone is not proof of PCIe camera support.
Check `lspci -nnk -d 14e4:1570`; the PCI address can vary. Both the checkout
installer and RPM/DEB pre-install scripts reject machines lacking this exact ID.
Post-install checks again before registering/building DKMS. No module is loaded
or firmware downloaded during package installation.

## Fedora

On the Mac with the PCIe camera:

```bash
lspci -nnk -d 14e4:1570
sudo dnf install dkms gcc make kernel-devel-$(uname -r) kernel-headers v4l-utils pciutils
sudo bash camera/scripts/install-camera.sh /absolute/path/macbook-facetimehd-dkms-0.7.2.git20260929-1.fc44.noarch.rpm
```

Or install that RPM directly with `dnf install` after confirming hardware.
Its own pre-install guard still runs. Matching `kernel-devel` for the running
kernel is required; installing headers only for a newer kernel is insufficient.

## Debian / Ubuntu

```bash
lspci -nnk -d 14e4:1570
sudo apt install dkms build-essential linux-headers-$(uname -r) v4l-utils pciutils
sudo bash camera/scripts/install-camera.sh /absolute/path/macbook-facetimehd-dkms_0.7.2.git20260929-1_all.deb
```

The DEB uses Debian package names (`xz-utils`, `linux-headers-*`) and `/lib/firmware`;
the RPM uses Fedora dependencies (`xz`, `kernel-devel`) and `/usr/lib/firmware`.
Runtime helpers share the portable `/usr/libexec/macbook-facetimehd/` path.
The package has no systemd service, kernel dependency override or modules-load file.

## Firmware and activation

If a working `facetimehd/firmware.bin` and calibration files are already installed,
they are retained automatically. After installing the package, finish setup with one command (the checkout installer already runs it):

```bash
sudo macbook-facetimehd setup
```

The [pinned firmware tool](https://github.com/patjak/facetimehd-firmware/tree/60ee21228d9ca00a7bd84fdaefaff00a81f1db91)
fetches verified byte ranges from Apple's HTTPS CDN, checks the driver, firmware,
assistant and eleven calibration files, then installs on this computer. It uses
firmware 5.60.0; extraction was checked here, camera operation with this firmware
was not streamed on the development Mac. The older upstream wiki's 1.43 recommendation
predates this extractor update. No proprietary blobs are redistributed.
If firmware already exists, the command refuses to overwrite it unless passed
`--replace`; that option first backs it up under `/var/lib/macbook-facetimehd/`.

`modprobe facetimehd` resolves `videodev`, `videobuf2-v4l2`, `videobuf2-common` and
`videobuf2-dma-sg` through kernel module dependency metadata. Names can vary by
kernel. No hard-coded modprobe ordering, copied V4L2 modules or vermagic editing
is used. DKMS rebuilds the module on kernel updates when matching headers exist.

`setup` obtains firmware only if missing and rebinds only the matching PCIe
camera when another driver owns it. Close camera applications before setup.
The lower-level `activate` command stops and names a conflicting binding.
After checking that no camera application is using it, explicitly run
`sudo macbook-facetimehd activate --rebind` to unbind **only matching camera PCI
devices** and bind them to facetimehd. There is no global bdc_pci blacklist or
module unload. Secure Boot may require signing/enrolling the DKMS key.

## Verification / limitations

```bash
uname -r
lspci -nnk -d 14e4:1570
dkms status -m facetimehd
lsmod | grep -E 'facetimehd|videodev|videobuf2'
v4l2-ctl --list-devices
ls -l /dev/video*
modinfo -F depends facetimehd
sudo journalctl -k -b | grep -Ei 'facetimehd|firmware|videobuf2'
```

The camera need not be `/dev/video0`. Match its PCI address and driver, especially
when USB cameras are attached. `test-stream` selects a node beneath matching PCI
hardware and captures 30 frames into `/dev/null` (no image is saved); a visual
preview is still needed to check color, exposure and calibration.

The upstream driver remains experimental. Suspend/resume, exposure/calibration,
Secure Boot and application/device permissions need hardware verification.
This revision compiled on Fedora 44 kernels 7.2.6, 7.2.7 and 7.2.8; this does not
guarantee other kernels or successful streaming. A real PCIe camera is absent
on the development Mac. The user confirmed a previously working installation on
MacBookPro14,1 and authorized delivery without repeating the full hardware
checklist. This packaged snapshot was build-tested; streaming, boot/resume and
Debian installation of this exact snapshot were not independently repeated.
See [optional diagnostic checklist](docs/HARDWARE-TEST.md).

Remove only the camera package with `dnf remove macbook-facetimehd-dkms` or
`apt remove macbook-facetimehd-dkms`. DKMS unregisters this snapshot. Previously
loaded module code stays until it is unloaded or the Mac is rebooted. Firmware
extracted by the user is intentionally not deleted; it may be used by other
camera installations. If another facetimehd DKMS/package is present, record its
version and remove that separate registration deliberately before installing
this one. The package conflicts with common facetimehd-dkms/bcwc-pcie-dkms names.

## Build and source attribution

`python3 camera/build.py --output /absolute/output/path` creates RPM, source RPM
and DEB from clean staging without root. Requires Python, GNU tar, rpmbuild and
dpkg-deb. No network, module installation or firmware download is part of builds.
Run `python3 camera/tests/test_camera.py -v` for hardware gating tests.
The unmodified driver sources are pinned to upstream commit `1f52306`; GPLv2
licenses, copyright notices and local modifications are recorded in
[UPSTREAM.md](UPSTREAM.md). Package/DKMS version: `0.7.2.git20260929`.
