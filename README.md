# MacBook Pro 13" (2017) on Linux

One package per feature for the 2017 13-inch MacBook Pro on Fedora, Debian
and Ubuntu: download the file for your model and distribution, install it,
reboot.

## 1. Which model do you have?

```bash
cat /sys/class/dmi/id/product_name
```

- **MacBookPro14,1** (A1708): function keys, no Touch Bar.
- **MacBookPro14,2** (A1706): Touch Bar and Touch ID.

## 2. Download what you need

All files are in the [latest release](https://github.com/vfontanela/macbookpro14-linux-support/releases/latest).

| Feature | 14,1 | 14,2 | Fedora | Debian / Ubuntu |
|---|:-:|:-:|---|---|
| [Speakers and microphone](audio/) | ✓ | ✓ | `mbp-cirrus-audio-dkms-2.0-1.noarch.rpm` | `mbp-cirrus-audio-dkms_2.0-1_all.deb` |
| [Wi-Fi: 5 GHz DFS channels](wifi-bcm4350/) | ✓ | | `brcmfmac-bcm4350-dfs-dkms-2.0-1.noarch.rpm` | — |
| [Wi-Fi: 2.4 and 5 GHz](wifi-bcm43602/) | | ✓ | `brcmfmac43602-mbp14-2-nvram-2.0-1.noarch.rpm` | `brcmfmac43602-mbp14-2-nvram_2.0-1_all.deb` |
| [FaceTime camera](camera/) | ✓ | | `macbook-facetimehd-dkms-0.7.2.git20260929-1.fc45.noarch.rpm` | `macbook-facetimehd-dkms_0.7.2.git20260929-1_all.deb` |
| [Touch Bar and Touch ID](touchid/) | | ✓ | `t1bridge-0.1.12-fedora-45-packages.tar.gz` | `t1bridge-0.1.12-debian-13-packages.tar.gz`, `t1bridge-0.1.12-ubuntu-26.04-packages.tar.gz` |
| [Touch Bar only (older driver)](touchbar/) | | ✓ | `mbp-t1-touchbar-dkms-1.0-4.noarch.rpm` | `mbp-t1-touchbar-dkms_1.0-4_all.deb` |

On the 14,2 the camera already works without a package. Pick **one** Touch Bar
option: Touch ID needs the T1 chip in a mode the older driver cannot use.

## 3. Install

Fedora:

```bash
sudo dnf install kernel-devel-$(uname -r)    # needed by every DKMS package
sudo dnf install ./mbp-cirrus-audio-dkms-2.0-1.noarch.rpm
sudo reboot
```

Debian / Ubuntu:

```bash
sudo apt install linux-headers-$(uname -r)
sudo apt install ./mbp-cirrus-audio-dkms_2.0-1_all.deb
sudo reboot
```

Do the same with each file you downloaded. Two features need one more step:

- **Camera:** run `sudo macbook-facetimehd setup` once. It extracts the camera
  firmware from Apple's servers on your machine.
- **Touch Bar and Touch ID:** extract the archive and run `sudo ./install.sh`
  from the distribution folder. After the reboot, register a fingerprint; see
  [touchid/](touchid/).

Remove a package with `sudo dnf remove <name>` or `sudo apt remove <name>`.
Packages that compile a kernel module (DKMS) rebuild it automatically after
kernel updates.

## What was tested

| Package | Tested on |
|---|---|
| Audio | MacBookPro14,1 and 14,2 (Fedora 44, 45); builds on Ubuntu 26.04. Needs Linux 6.17 or newer, so Debian 13 needs a backports kernel. |
| Wi-Fi 14,1 (DFS) | MacBookPro14,1, Fedora 44, kernel 7.2.4 (channel 116). Source builds on Linux 7.2 only. |
| Wi-Fi 14,2 | MacBookPro14,2, Fedora 44 and 45, both bands. |
| Camera 14,1 | MacBookPro14,1, Fedora 44. |
| Touch Bar and Touch ID | MacBookPro14,2, Fedora 45: Touch Bar, enrollment, sudo with the fingerprint. Debian 13 and Ubuntu 26.04 packages only tested in containers. |
| Touch Bar (older driver) | MacBookPro14,2, Fedora 44; builds on Debian 13 and Ubuntu 26.04. |

Every package was also installed, built and removed in Fedora 45, Debian 13
and Ubuntu 26.04 containers. Packages are not signed; check downloads against
`SHA256SUMS` in the release. With Secure Boot, DKMS modules must be signed with
a key you enroll (`mokutil`).

## Build the packages yourself

```bash
bash build.sh                  # everything, into dist/
bash build.sh audio touchbar   # only some: audio wifi-bcm4350 wifi-bcm43602 touchbar camera touchid
```

Needs podman or docker; all builds run in containers.

## Credits

The drivers come from [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
(audio), the Linux `brcmfmac` driver (Wi-Fi),
[patjak/facetimehd](https://github.com/patjak/facetimehd) (camera),
[standardagents/t1bridge](https://github.com/standardagents/t1bridge) (Touch ID)
and [parport0/mbp-t1-touchbar-driver](https://github.com/parport0/mbp-t1-touchbar-driver)
(older Touch Bar driver). This repository packages them for these two models.
Each folder lists its exact upstream version and license.
