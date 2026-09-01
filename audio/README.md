# Cirrus audio on MacBook Pro

Linux support for the Cirrus Logic CS8409 codec and internal amplifiers used by
2017 MacBook Pro models. The driver comes from
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro).

Validated on:

| Model | Distribution | Kernel | Result |
|---|---|---|---|
| MacBookPro14,1 | Fedora 44 | 7.1.12 | Internal speakers and microphone working with the same driver |
| MacBookPro14,2 | Fedora 44 | 7.1.10 | Internal speakers and microphone working |
| 2017+ MacBook Pro / iMac Pro | Ubuntu-based | 7.x | Supported by the packaged DKMS workflow |

## Fedora 44, kernel 7.1.10

Install every dependency for the running kernel:

```bash
sudo dnf install git dkms gcc make patch wget   kernel-devel-$(uname -r) kernel-headers
```

The exact `kernel-devel` package must exist for `uname -r`. Reboot into
an installed kernel with matching development files before continuing if DNF
cannot find it.

Clone upstream and run its DKMS installer:

```bash
git clone https://github.com/davidjo/snd_hda_macbookpro.git
cd snd_hda_macbookpro
sudo bash ./dkms.sh
```

The script downloads and patches the sound/HDA sources for the running kernel.
It therefore needs network access for a kernel version that is not already
cached.

### Workaround for a truncated linux-7.1.10.tar.xz

If the build reports an unexpected end of file, an XZ integrity error, or an
incomplete `linux-7.1.10.tar.xz`, remove the partial archive and download it
again instead of trying to extract it:

```bash
rm -f linux-7.1.10.tar.xz
wget --continue   https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.10.tar.xz
xz -t linux-7.1.10.tar.xz
```

Keep the verified archive in the directory where `dkms.sh` expected the
download, then rerun:

```bash
sudo bash ./dkms.sh
```

Do not continue while `xz -t` fails; DKMS cannot build from a truncated
kernel archive.

### Complete or retry the DKMS build

First obtain the registered module name and version:

```bash
dkms status
```

Then build and install the entry reported by that command for the running
kernel, replacing `<module>/<version>` literally with the reported value:

```bash
sudo dkms build <module>/<version> -k $(uname -r)
sudo dkms install <module>/<version> -k $(uname -r)
sudo depmod -a
sudo reboot
```

After reboot:

```bash
dkms status
lsmod | grep cs8409
journalctl -k -b | grep -Ei 'cs8409|cirrus|snd_hda'
```

Select **Analogue Stereo Output**, or **Analogue Stereo Duplex** when the
internal microphone is also required.

## Ubuntu and Kubuntu package

The existing Debian package workflow remains supported:

```bash
sudo apt install dkms build-essential patch wget   linux-headers-$(uname -r)   linux-source-$(uname -r | cut -d- -f1)
sudo dpkg -i mbp-cirrus-audio-dkms_1.0-1_all.deb
sudo apt -f install   # only if dpkg reports missing dependencies
sudo reboot
```

The packaged source is vendored in this repository and caches patched HDA
sources by kernel version. A genuinely new upstream kernel version can still
require a new kernel-source download.

## Notes

- DKMS automates rebuilding; it does not remove the requirement for matching
  kernel development files and sound/HDA source.
- Fedora 44 was validated on MacBookPro14,1 with kernel 7.1.12 and on
  MacBookPro14,2 with kernel 7.1.10. Both use the same driver workflow.
- Driver and codec patches are maintained by davidjo and contributors.
