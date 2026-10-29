# FaceTime camera (MacBookPro14,1)

Package: `macbook-facetimehd-dkms`. Makes the PCIe FaceTime HD camera
(`14e4:1570`) work, with [patjak/facetimehd](https://github.com/patjak/facetimehd)
built by DKMS.

Only for Macs where `lspci -nn -d 14e4:1570` finds the camera. The
MacBookPro14,2 camera is a USB device that already works (`uvcvideo`); the
package refuses to install there.

After installing, run once:

```bash
sudo macbook-facetimehd setup
```

It keeps working firmware if you already have it. Otherwise it downloads the
needed parts of Apple's macOS update over HTTPS, extracts firmware 5.60.0 and
the sensor calibration files, checks their hashes and installs them. No Apple
firmware is in the package. It then binds the camera to `facetimehd`. Close
camera applications first.

Check:

```bash
v4l2-ctl --list-devices
sudo macbook-facetimehd test-stream      # captures 30 frames, saves nothing
```

- The camera is not necessarily `/dev/video0`.
- `sudo macbook-facetimehd firmware --replace` re-extracts the firmware and
  backs up the old one to `/var/lib/macbook-facetimehd/`.
- Removing the package leaves the extracted firmware in place.
- The package conflicts with other `facetimehd-dkms` / `bcwc-pcie-dkms`
  packages; remove those first.

Tested: worked on a MacBookPro14,1 with Fedora 44. This exact build compiled
on Fedora kernels 7.2.6 to 7.2.11; streaming with it was not repeated.
Suspend/resume is untested. More checks: [docs/HARDWARE-TEST.md](docs/HARDWARE-TEST.md).
Pinned upstream commits and licenses (GPL-2.0): [UPSTREAM.md](UPSTREAM.md).

Build: `python3 camera/build.py --output OUTDIR`. Tests: `python3 camera/tests/test_camera.py`.
