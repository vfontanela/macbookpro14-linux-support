# Touch Bar, older driver (MacBookPro14,2)

Package: `mbp-t1-touchbar-dkms`. Turns on the Touch Bar (function keys, media
keys) and the ambient light sensor through the T1 chip, without Touch ID.

> For Touch ID use [touchid/](../touchid/) instead. It drives the Touch Bar too.
> The two packages conflict: the T1 offers either this mode or the Secure
> Enclave, never both.

It builds three modules with DKMS, from
[parport0/mbp-t1-touchbar-driver](https://github.com/parport0/mbp-t1-touchbar-driver)
(originally by Ronald Tschalär): `apple-ibridge` (the T1 USB hub),
`apple-ib-tb` (Touch Bar) and `apple-ib-als` (light sensor). A small service,
`mbp-t1-touchbar-bind`, rebinds the T1's HID interfaces when another driver
(`hid-sensor-hub`) grabs them first. It runs at boot and when the device
reappears.

Works on T1 Macs: MacBookPro13,2, 13,3, 14,2 and 14,3. Not on T2 Macs.

Check after the reboot:

```bash
lsmod | grep -E 'apple_ibridge|apple_ib_tb|apple_ib_als'
journalctl -b -u mbp-t1-touchbar-bind
```

- Touch Bar dark: `sudo systemctl restart mbp-t1-touchbar-bind`, or reboot
  once more.
- `lsusb` shows `05ac:1281` (Recovery Mode) instead of `05ac:8600`: the T1
  firmware is missing. Boot macOS once to restore it.
- Settings (Fn mode, brightness, dimming) are in
  `/etc/modprobe.d/mbp-t1-touchbar.conf`.

Build: `bash touchbar/build.sh OUTDIR`. Tests: `python3 touchbar/tests/test_binding.py`.
License: GPL-2.0 (see `LICENSE`).
