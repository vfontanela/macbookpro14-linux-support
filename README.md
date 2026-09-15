# macbookpro14-linux-support

Linux support documentation and packages for the 2017 13-inch **MacBookPro14,x** family: MacBookPro14,1 (function keys) and MacBookPro14,2 (Touch Bar).

## Support matrix

| Component | MacBookPro14,1 (A1708, no Touch Bar) | MacBookPro14,2 (A1706, Touch Bar) | Documentation |
|---|---|---|---|
| Internal audio | Cirrus CS8409 with `snd_hda_macbookpro` DKMS | Cirrus CS8409 with `snd_hda_macbookpro` DKMS | [audio/README.md](audio/README.md) |
| Wi-Fi | BCM4350 `[14e4:43a3]`; `brcmfmac-bcm4350-dfs/1.0` DKMS for DFS UNII-2e | BCM43602 `[14e4:43ba]`; complete calibrated board NVRAM | [wifi/README.md](wifi/README.md) |
| Touch Bar / ambient light sensor | Not present; standard function-key row | T1 iBridge with `mbp-t1-touchbar` DKMS | [touchbar/README.md](touchbar/README.md) |

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
