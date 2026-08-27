# macbookpro14-linux-support

Linux support documentation and packages for the 2017 Touch Bar
**MacBookPro14,2**: Broadcom Wi-Fi, Cirrus CS8409 audio and the T1 Touch Bar.

## Tested configurations

| Component | Fedora 44, kernel 7.1.10 | Ubuntu / Kubuntu | Documentation |
|---|---|---|---|
| T1 Touch Bar and ambient light sensor | Validated with `mbp-t1-touchbar` DKMS | Supported with the existing Debian package | [touchbar/README.md](touchbar/README.md) |
| Cirrus CS8409 internal audio | Validated with `snd_hda_macbookpro` DKMS | Supported with the existing Debian package | [audio/README.md](audio/README.md) |
| Broadcom BCM43602 Wi-Fi | Validated on 2.4 GHz and 5 GHz with complete calibrated NVRAM | Supported with the same board NVRAM | [wifi/README.md](wifi/README.md) |

## Fedora 44 highlights

- Install matching `kernel-devel-$(uname -r)` and `kernel-headers`
  before building DKMS modules.
- The Cirrus driver was validated on kernel 7.1.10; its first build can require
  the full kernel source archive.
- BCM43602 5 GHz required the complete MacBookPro14,2 NVRAM, not a minimal
  parameter file.
- The NVRAM `macaddr` must come from `ethtool -P <interface>`, because
  the active interface address can be randomized.

Ubuntu and Kubuntu instructions have been retained in each component guide.
