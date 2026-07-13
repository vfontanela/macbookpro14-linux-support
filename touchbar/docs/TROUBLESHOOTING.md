# Troubleshooting

## `dkms build` fails with `make: *** Sem alvo. Pare.` / `No targets. Stop.`

This means the module's Makefile was invoked in the wrong mode. Its
`ifneq ($(KERNELRELEASE),)` branch only *defines* `obj-m` — it has no
runnable default target on its own. It's meant to be invoked by the
kernel's own build system via `make -C $KDIR M=$PWD modules`, which is
exactly what DKMS does **by default** when you don't override `MAKE[0]`
in `dkms.conf`.

Fix: don't set a custom `MAKE[0]` in `src/dkms.conf` — let DKMS use its
default invocation. (This exact bug shipped in package version 1.0-1
and was fixed in 1.0-2.)

## Build fails with real compiler errors (undefined symbol, wrong
## argument count, etc.)

This means an actual kernel API changed between the driver's last
tested kernel and yours. Steps:

1. `cat /var/lib/dkms/mbp-t1-touchbar/0.3/build/make.log`
2. Find the first `error:` line (ignore warnings) — it'll point at a
   specific function call in `apple-ib-tb.c`, `apple-ib-als.c`, or
   `apple-ibridge.c`.
3. Compare that function's signature against the kernel headers in
   `/usr/src/linux-headers-$(uname -r)/include/...` (or
   `/lib/modules/$(uname -r)/build/include/...`) to see what changed.
4. Patch the `.c` file in `src/`, bump `PACKAGE_VERSION` in
   `src/dkms.conf` if you want DKMS to treat it as a new module
   version, then `./build.sh` again.

## Module builds and loads, but the Touch Bar stays blank

1. Confirm the T1 isn't in recovery mode:
   ```
   lsusb | grep 05ac
   ```
   `05ac:8600` = good. `05ac:1281` = firmware missing, boot macOS once.

2. Confirm the modules are actually loaded:
   ```
   lsmod | grep -E "apple_ibridge|apple_ib_tb|apple_ib_als"
   ```

3. Check whether the USB rebind actually happened:
   ```
   journalctl -u mbp-t1-touchbar-bind.service --no-pager
   lsusb -t | grep -A2 05ac:8600
   ```
   If the log says "not found after waiting", the device may not have
   enumerated yet at boot — try `sudo systemctl restart
   mbp-t1-touchbar-bind.service` once the system is fully up.

4. As a last resort, do the rebind manually:
   ```
   BUSID=$(lsusb | awk '/05ac:8600/{print $2"-"$4}' | tr -d ':')
   # or just find it under /sys/bus/usb/devices/*/idProduct == 8600
   echo -n "$BUSID" | sudo tee /sys/bus/usb/drivers/usb/unbind
   echo -n "$BUSID" | sudo tee /sys/bus/usb/drivers_probe
   ```

## Touch Bar works but goes blank/dim too aggressively (or never dims)

Edit `/etc/modprobe.d/mbp-t1-touchbar.conf` — `idle_timeout` and
`dim_timeout` are in seconds, `-1` disables them. Reload with:
```
sudo modprobe -r apple-ib-tb && sudo modprobe apple-ib-tb
```

## Touch Bar goes blank after resume from suspend

The udev rule (`udev/99-mbp-t1-touchbar.rules`) should catch the
iBridge re-enumerating and re-trigger the bind service automatically.
If it doesn't, check:
```
journalctl -u mbp-t1-touchbar-bind.service --since "5 minutes ago"
```
and confirm the rule is loaded with `udevadm control --reload-rules`.

## Secure Boot / module signing

If Secure Boot is enabled, unsigned out-of-tree modules like this one
will be rejected by the kernel. DKMS generates a MOK (Machine Owner
Key) automatically on first build (`update-secureboot-policy`); you'll
need to enroll it via `mokutil --import` and confirm at the next
reboot's blue MOK Manager screen. If Secure Boot is disabled (as is
common on Hackintosh-style setups), this doesn't apply.
