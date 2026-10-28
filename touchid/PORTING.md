# Porting T1Bridge beyond Arch

These problems only appeared outside Arch. They are listed in the order they
were found on a MacBookPro14,2 with Fedora 45.

## 1. Three USB configurations, one with Touch ID

| Config | Exposes | Used by |
|---|---|---|
| 1 | Touch Bar HID; the T1 draws the keys itself | legacy `apple-ibridge`/`apple-ib-tb` |
| 2 | Secure Enclave (interface 7, class `ff/f9/11`), private NCM link, Touch Bar display (the host draws it), camera | macOS, T1Bridge |
| 3 | a variant without the Secure Enclave | — |

Touch ID requires configuration 2. That is a hardware constraint, which is
why the legacy Touch Bar driver and Touch ID are mutually exclusive.

## 2. usbmuxd forces the iBridge back to configuration 1

Fedora, Debian 13 and Ubuntu 26.04 all ship this in
`/usr/lib/udev/rules.d/39-usbmuxd.rules`:

```
ENV{PRODUCT}=="5ac/8600/*", ACTION=="add", ..., ATTR{bConfigurationValue}="1", ...
```

A few seconds after boot it undoes `t1_cfgsel`, and the Touch Bar stays dark.
The fix is a copy of that rule without the `5ac/8600` entries, written to
`/etc/udev/rules.d/` (the same file name in /etc wins). The copy's first line
marks it as the package's. An administrator's unmarked file is never replaced
or removed. The copy is regenerated whenever usbmuxd changes (RPM
`%triggerin`, dpkg `interest-noawait` trigger) and, on Fedora, also in
`%posttrans`: 0.1.12-3 listed the file as `%ghost`, and rpm erases a ghost
dropped by the new package **after** that package's trigger has run.
Upgrades and admin-file cases were tested in containers.

## 3. SELinux: services ran as `init_t` (Fedora)

`/usr/lib/t1bridge/*` inherits `lib_t`, and systemd does not transition on
`lib_t`. The services therefore stayed `init_t` and were denied the T1
`hidraw`/`usbfs` nodes (`usb_device_t`). The symptom was
`t1-touchbar-hw: Touch Bar input failed` in a loop. The confined `fprintd_t`
also could not connect to the broker socket. The `t1bridge` module labels the
directory `bin_t` (services run as `unconfined_service_t`) and allows
`fprintd_t` to `connectto` that socket. This is the usual treatment for a
third-party service, not least-privilege confinement; a dedicated domain and
socket type are future work.

## 4. Initramfs regenerated too early (Fedora)

Regenerating in `%post` happened before dnf erased `mbp-t1-touchbar-dkms`,
so the legacy driver's `modules-load.d` entry ended up in the initramfs.
Regeneration now runs in `%posttrans`. DKMS and dracut failures are reported:
the scriptlet fails visibly and checks that `t1_cfgsel` is in the running
kernel's initramfs. On Debian/Ubuntu, `postinst` fails, so the package stays
unconfigured. Debian `prerm` no longer removes the DKMS tree on upgrade.

## 5. Exact-version dependents of libfprint/fprintd

`fprintd-pam` and `libfprint-devel` (Fedora), and `libfprint-2-tod1`, `-dev`
and GIR (Debian/Ubuntu), require the exact rebuilt version. If the installer
selected only the main packages, `--allowerasing` would have **removed**
`fprintd-pam`. The installers therefore replace every installed member of the
set. They let dnf/apt show the transaction instead of passing `-y`, lock the
set, and record which locks they added.

## 6. A different libfprint on each distribution

| Distribution | libfprint | Driver patch |
|---|---|---|
| Arch (upstream) | 1.94.100 (pinned commit) | original |
| Fedora 45 | 1.94.100 | original, applies unchanged |
| Debian 13 | 1.94.9 | ported: list-based `default_drivers`/`endian_independent_drivers`; helper placement |
| Ubuntu 26.04 | 1.95.1+tod1 | ported: the `FpDeviceType` enum has a different order (TOD ABI), so `FP_DEVICE_TYPE_USB_PRESENCE` is appended **last**; the new helper is `G_GNUC_INTERNAL`, otherwise `dpkg-gensymbols` rejects it as a new `libfprint-2-tod1` symbol |

The new device type is handled in every `switch` over `FpDeviceType`, because
the patch turns `-Wswitch-enum` into an error. The udev rule and hwdb
generators only consider `FP_DEVICE_TYPE_USB`, so the iBridge never receives
an autosuspend entry. The fprintd patch (start enrollment directly when the
driver checks for duplicates itself) applies unchanged everywhere.

## 7. Smaller items

- **First enrollment:** it can fail once with `prepare device keybag
  failed`, notably right after `t1-xart-storage` restarts. It succeeds on the
  retry. Upstream documents the same pattern.
- **Firewall:** xART needs inbound IPv6 TCP 61500 on the T1 NCM interface.
  The Fedora Workstation default zone already allows 1025-65535. On
  Debian/Ubuntu, act only if ufw is enabled.
- **Rust:** T1Bridge needs rustc 1.88 or newer (edition 2024). Debian 13 has
  1.85, so the Debian build uses `rustup`.
- **Per-distribution binaries:** every package is built in a container of
  its target release.
