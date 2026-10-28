# Touch ID and Touch Bar (T1Bridge)

Packages that make the **Touch ID fingerprint reader** of T1 MacBook Pros work
on Linux, built from [T1Bridge](https://github.com/standardagents/t1bridge)
0.1.12 (pinned, see [UPSTREAM.md](UPSTREAM.md)). Upstream only packages for
Arch; this component adds Fedora 45, Debian 13 and Ubuntu 26.04 packaging.
The adaptations are explained in [PORTING.md](PORTING.md). Guides in
Portuguese are in [docs/pt-BR](docs/pt-BR/).

> **Experimental.** Tested end to end on one MacBookPro14,2 with Fedora 45
> (kernel 7.2.11): Touch Bar, enrollment, `verify-match`, sudo with the
> fingerprint, and sudo with the password when the sensor is not touched.
> The Debian/Ubuntu packages build and install in clean containers but have
> **not been run on hardware**. Lock screen/GDM, password fallback with the
> service stopped, suspend/resume and other models are unverified.

## Touch ID or the legacy Touch Bar package — not both

| | [`touchbar/`](../touchbar/README.md) (`mbp-t1-touchbar-dkms`) | `touchid/` (T1Bridge) |
|---|---|---|
| Touch Bar | yes; the T1 draws the keys | yes; Linux draws it (`appletbdrm` + `t1-touchbar`) |
| Touch ID | **impossible** | yes |
| Ambient light sensor | yes | yes (`iio-sensor-proxy`) |
| FaceTime camera | stock `uvcvideo` | patched `uvcvideo` (DKMS) |

The iBridge (`05ac:8600`) has three USB configurations, and only one is
active at a time. The legacy driver needs configuration 1, which has no
Secure Enclave interface. Touch ID needs configuration 2, where the T1 stops
drawing the Touch Bar. The packages conflict on purpose:
`t1bridge-dkms` disables the legacy modules, and on Fedora it replaces
`mbp-t1-touchbar-dkms`.

Supported models: MacBookPro13,2, 13,3, 14,2 (tested) and 14,3. Not
MacBookPro14,1 (no Touch Bar), not T2 Macs, not Apple Silicon.

## Before anything: back up `FDRData`

Touch ID needs **this Mac's** factory calibration,
`EFI/APPLE/EMBEDDEDOS/FDRData`, which Apple keeps on the original EFI
partition. Without it Touch ID cannot work, and another Mac's copy does not
work either. Keep the backup private and off the machine:

```bash
sudo ls -l /boot/efi/EFI/APPLE/EMBEDDEDOS/
sudo tar -C /boot/efi -czf ~/apple-efi-backup.tar.gz EFI/APPLE
```

## Install from a release

Download your distribution's `*-packages.tar.gz` bundle from the release,
extract it, and run the installer from the distribution folder:

```bash
# Fedora 45
sudo ./install.sh
# Debian 13 / Ubuntu 26.04
sudo apt install dkms linux-headers-$(uname -r)
sudo ./install.sh
```

The installer checks the model, the distribution, the architecture and
`SHA256SUMS`. dnf/apt then **shows the transaction and asks** before applying
it. On Fedora, the only expected removal is `mbp-t1-touchbar-dkms`. The
installer also locks the rebuilt `libfprint`/`fprintd`
(`dnf versionlock` / `apt-mark hold`) and records the locks it added in
`/var/lib/t1bridge-port/`. **PAM is not changed.**

If a DKMS build or the initramfs fails, the installation prints
`t1bridge-dkms: ERROR: ...`. Do not reboot until it is fixed; the usual cause
is missing kernel headers or `kernel-devel` for the running kernel.

After a reboot the Touch Bar lights up. Then, in a terminal **of the graphical
session** (Polkit asks for your password):

```bash
sudo systemctl start t1bridge-import.service   # import the Apple calibration
fprintd-enroll -f right-index-finger           # lift and touch repeatedly
fprintd-verify -f right-index-finger           # expect verify-match
```

The first enrollment can fail once with `enroll-unknown-error` while the
Secure Enclave creates its keybag. Retry, and never delete `/var/lib/t1bridge`.

### Fingerprint login, sudo and Polkit

Keep a root shell open and a working password before changing PAM.

- Fedora: `authselect current`. The Workstation default usually lists
  `with-fingerprint`. If it does not:
  `sudo authselect enable-feature with-fingerprint && sudo authselect apply-changes`.
- Debian/Ubuntu: `sudo pam-auth-update --enable fprintd`.

Test each consumer (sudo, Polkit, lock screen, login) separately: with the
fingerprint, with the password without touching the sensor, with the password
while the service is stopped
(`sudo systemctl stop t1-touchid-auth.service t1bridge-fingerprint.socket t1-touchid-auth.socket`),
and after cancelling the prompt.

## Build

```bash
bash touchid/build.sh /absolute/output/path                    # all targets
bash touchid/build.sh /absolute/output/path fedora-45          # or debian-13, ubuntu-26.04
SKIP_FPRINT=1 bash touchid/build.sh /abs/out debian-13         # only the t1bridge packages
```

Requires `git` and `podman` or `docker`. Each target builds in a clean
container of that distribution, against its own libraries. Network access is
needed for the upstream clone, crates and distribution packages.

## What changes on the system

- `t1bridge`: services, the Apple-data importer, the Touch ID broker
  (`/run/t1bridge/fingerprint.sock`, root-only) and the Touch Bar renderer.
- `t1bridge-dkms`: `t1_cfgsel`, `apple_t1_ncm`, `appletbdrm` (T1) and
  `uvcvideo`, rebuilt for every kernel. `t1_cfgsel` is added to the initramfs
  (dracut or initramfs-tools).
- `t1bridge-selinux` (Fedora): labels `/usr/lib/t1bridge` `bin_t` and lets the
  confined fprintd reach the broker socket. The services run as
  `unconfined_service_t`; this is **not** a dedicated confinement policy.
- The distribution's `libfprint` (with the `t1bridge` driver) and `fprintd`,
  rebuilt under the same names and locked.
- `/etc/udev/rules.d/39-usbmuxd.rules`: a marked copy of usbmuxd's rule
  without the iBridge entries. Without it, usbmuxd forces the iBridge back to
  configuration 1. An administrator's own file with that name is never
  replaced or removed; the package warns instead.

## Troubleshooting

```bash
sudo t1bridge status
cat /sys/bus/usb/devices/*/bConfigurationValue      # the iBridge must be 2
journalctl -b -u t1-touchbar-hw -u t1-touchid-auth -u 't1-xart-storage@*' -u fprintd
dkms status t1bridge-dkms
sudo ausearch -m avc -ts boot | grep -E 'fprintd|t1'  # Fedora
```

Opt-in detailed logs: upstream
[diagnostics.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/diagnostics.md).

## Removal

Keep a root shell open. Disable fingerprint PAM and test password login first.
Then remove the locks recorded in `/var/lib/t1bridge-port/`, remove
`t1bridge t1bridge-dkms` (and `t1bridge-selinux`), and return **every**
rebuilt `libfprint*`/`fprintd*`/`libpam-fprintd`/`gir1.2-fprint` package to the
distribution version. Check that `t1_cfgsel` has left the initramfs. The exact
commands are in the Fedora and Debian guides in [docs/pt-BR](docs/pt-BR/).
Protected state in `/var/lib/t1bridge` and the Apple EFI partition are never
deleted.

## Known limitations

- T1 functions may not recover after suspend
  ([upstream #14](https://github.com/standardagents/t1bridge/issues/14)).
- Packages and RPMs are unsigned; SHA256SUMS show consistency, not who
  published them.
- Secure Boot is untested. The DKMS modules are unsigned.
