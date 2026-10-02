# macbookpro14-linux-support

Linux support documentation and packages for the 2017 13-inch **MacBookPro14,x** family: MacBookPro14,1 (function keys) and MacBookPro14,2 (Touch Bar).

## Support matrix

| Component | MacBookPro14,1 (A1708, no Touch Bar) | MacBookPro14,2 (A1706, Touch Bar) | Documentation |
|---|---|---|---|
| Internal audio | Cirrus CS8409 with `snd_hda_macbookpro` DKMS | Cirrus CS8409 with `snd_hda_macbookpro` DKMS | [audio/README.md](audio/README.md) |
| Wi-Fi | BCM4350 `[14e4:43a3]`; `brcmfmac-bcm4350-dfs/1.0` DKMS for DFS UNII-2e | BCM43602 `[14e4:43ba]`; complete calibrated board NVRAM | [wifi/README.md](wifi/README.md) |
| Touch Bar / ambient light sensor | Not present; standard function-key row | T1 iBridge with `mbp-t1-touchbar` DKMS | [touchbar/README.md](touchbar/README.md) |
| Camera / FaceTime HD | PCIe `14e4:1570`: separate facetimehd DKMS package; user-confirmed working camera | USB iBridge / `uvcvideo` observed on the development Mac; no PCIe package needed | [camera/README.md](camera/README.md) |

## Tested configurations

| Model | Distribution / kernel | Validated result |
|---|---|---|
| MacBookPro14,1 | Fedora 44, kernel 7.1.12 | CS8409 audio; BCM4350 2.4/5 GHz, including DFS channel 116 with patched `brcmfmac` |
| MacBookPro14,1 | Fedora 44, kernel 7.2.5 | BCM4350 Wi-Fi requires `pcie_aspm=off` on the kernel command line (PCIe ASPM probe regression, unrelated to the DFS DKMS package); see [wifi/BCM4350-PCIe-ASPM-kernel7.2.5.md](wifi/BCM4350-PCIe-ASPM-kernel7.2.5.md) |
| MacBookPro14,2 | Fedora 44, kernel 7.1.10 | CS8409 audio; BCM43602 2.4/5 GHz; T1 Touch Bar and ambient light sensor |
| MacBookPro14,2 | Ubuntu / Kubuntu | Existing Debian package workflows for audio and Touch Bar; board-specific BCM43602 NVRAM |

## Fedora 44 highlights

- Install matching `kernel-devel-$(uname -r)` and `kernel-headers` before building DKMS modules.
- Both models use the same `snd_hda_macbookpro` audio solution.
- MacBookPro14,1 has no Touch Bar and does not need a T1/iBridge package.
- BCM4350 DFS support on MacBookPro14,1 requires the one-line country-code fallback patch documented in [wifi/BCM4350-DFS.md](wifi/BCM4350-DFS.md).
- BCM4350 Wi-Fi on MacBookPro14,1 kernel 7.2.5 requires `pcie_aspm=off` on the kernel command line — a PCIe power-management regression that stops `brcmfmac` from probing the chip at all, unrelated to the DFS DKMS package. See [wifi/BCM4350-PCIe-ASPM-kernel7.2.5.md](wifi/BCM4350-PCIe-ASPM-kernel7.2.5.md).
- BCM43602 5 GHz on MacBookPro14,2 requires the complete board NVRAM, not a minimal parameter file. Its `macaddr` must come from `ethtool -P` because the active interface address can be randomized.

Ubuntu and Kubuntu instructions already present in each component guide have been retained.

## Camera installation by model

The new `camera/` component is independent of Touch Bar, audio and Wi-Fi.
Install it only when `lspci -nn -d 14e4:1570` finds the supported PCIe camera;
USB/iBridge cameras use `uvcvideo`. Both package families check hardware before
installing/configuring DKMS. Driver/tool GPL licenses and pinned upstream
revisions are recorded in `camera/UPSTREAM.md`; proprietary firmware is obtained
and extracted only on the user's machine, never redistributed in packages.

Build the independent Touch Bar and camera RPM/DEB packages with
`bash tools/build-support.sh /absolute/output/path` (requires dpkg-deb,
rpmbuild, Python, make and tar). There is deliberately no metapackage requiring
both components on models that do not have both devices. The existing Touch Bar
1.0-3 sources/service/binding fix is preserved unchanged.

**MacBookPro14,1 (A1708):** install the camera RPM/DEB from the latest release,
then run `sudo macbook-facetimehd setup`. It keeps working firmware, extracts it
locally only if absent, and activates only the supported PCIe camera. The
checkout installer also completes setup automatically; see [camera/README.md](camera/README.md).

**MacBookPro14,2 (A1706):** keep the USB iBridge camera's `uvcvideo` support;
install the separate Touch Bar package if needed. Do not install facetimehd on
this model's USB camera. Both package families reject absent PCIe hardware.

The user confirmed FaceTime HD had already worked on the 14,1 and accepted
release without repeating all hardware tests. This packaged snapshot passed
clean builds; exact-snapshot streaming, Debian lifecycle and Secure Boot were
not independently validated. Optional diagnostics remain documented.
