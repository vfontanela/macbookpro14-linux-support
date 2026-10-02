# Optional diagnostics on the MacBookPro14,1 PCIe FaceTime HD

The user confirmed the previously working FaceTime HD installation was on
MacBookPro14,1 and authorized delivery without repeating this checklist.
These steps remain available for troubleshooting and future regression checks;
they are not a prerequisite for installing this release. This exact packaged
snapshot has build validation but has not been streamed on that PCIe hardware.

1. On Fedora 44 / kernel 7.2.8, save `uname -r`, `lspci -nnk -d 14e4:1570`,
   `dkms status -m facetimehd`, `modinfo -n facetimehd` and the DMI model name
   (`cat /sys/class/dmi/id/product_name`). Do not use the USB iBridge Mac for
   this PCIe test. Record existing working driver/firmware hashes for rollback.
2. Install matching kernel-devel and build tools. Remove any previous separate
   facetimehd DKMS registration deliberately after recording it. Install the
   camera RPM using `camera/scripts/install-camera.sh` (or directly via dnf).
   The package must register/build only facetimehd, never touch Touch Bar.
3. Retain previously working firmware for the first test. If absent, run
   `sudo macbook-facetimehd firmware`. Record whether the existing firmware or
   extracted 5.60.0 is used. Any deliberate replacement first creates a backup.
4. Run `sudo macbook-facetimehd activate`. If it reports bdc_pci ownership,
   close camera apps and explicitly retry `activate --rebind`. Confirm
   `lspci -nnk -d 14e4:1570` says `Kernel driver in use: facetimehd`.
5. Run `macbook-facetimehd diagnose`, `v4l2-ctl --list-devices`, `lsmod`,
   `ls -l /dev/video*` and `macbook-facetimehd test-stream`. Expected: an Apple
   Facetime HD device with the matching PCI address, its own video node, and
   30 frames captured without errors. /dev/video0 is not required.
6. Open a camera preview application; check a real image, color/exposure,
   indicator LED and application permissions. Close all camera applications.
7. Reboot and repeat detection/streaming. Test suspend/resume with the device
   closed, then open/stream again and collect kernel errors if any.
8. Install/boot a newer kernel with matching development files. Confirm DKMS
   rebuilt this snapshot and streaming works; record dkms status and kernel.
9. Test upgrade/reinstall and removal on a recoverable test system. Confirm
   this snapshot is removed from DKMS, user-extracted firmware is retained,
   and unrelated USB/UVC cameras and Touch Bar behavior stay intact.
10. Debian/Ubuntu still needs an independent install/load/stream/upgrade/remove
    test with matching linux-headers. RPM success does not validate the DEB's
    package-manager lifecycle. Secure Boot needs a signing/key-enrollment test
    if it is enabled on the target Mac.

Send the diagnostic output and results (without camera images unless desired).
If a step fails, preserve errors and firmware/driver
revision details. The installer intentionally refuses unsupported hardware.
