# Broadcom Wi-Fi on MacBookPro14,1 and MacBookPro14,2

The two 2017 13-inch models use different Broadcom devices and require different fixes:

| Model | Device | Required support |
|---|---|---|
| MacBookPro14,1 | BCM4350, PCI ID `14e4:43a3` | `brcmfmac-bcm4350-dfs/1.0` DKMS for DFS UNII-2e; see [BCM4350-DFS.md](BCM4350-DFS.md) |
| MacBookPro14,2 | BCM43602, PCI ID `14e4:43ba` | Complete calibrated MacBookPro14,2 board NVRAM, documented below |

Do not interchange NVRAM, firmware or regulatory blobs between chipsets.

## BCM4350 kernel compatibility

The corrected `brcmfmac-bcm4350-dfs/1.0` source package is [published here](https://github.com/vfontanela/macbookpro14-linux-support/releases/tag/bcm4350-dfs-1.0-kernel7.2.4-r1). The supplied build log records **exit code 0** for `7.2.4-200.fc44.x86_64`; post-reboot records show that kernel running and Wi-Fi connected at **5580 MHz / DFS channel 116**. See [sources](brcmfmac-bcm4350-dfs-1.0/), [build and validation evidence](bcm4350-evidence/kernel-7.2.4/), and the [kernel 7.2 correction and rebuild procedure](BCM4350-DFS.md#kernel-72-compatibility-update-2026-09-10).

The original documentation reported a `v7.1.12` source base, but the package records no verifiable upstream commit. The `KERNEL_VERSION(7, 2, 0)` cutoff is empirical. `modinfo` shows the resolved file, not proof of the exact loaded binary; matching `vermagic` does not guarantee full compatibility. Other kernels need their own build and runtime validation.

Kernel `7.2.5-200.fc44.x86_64` introduced a separate, unrelated failure: `brcmfmac` fails to probe the BCM4350 at all (`brcmf_pcie_probe: failed 14e4:43a3`), traced to a PCIe ASPM power-management regression rather than a DKMS/build problem. See [BCM4350-PCIe-ASPM-kernel7.2.5.md](BCM4350-PCIe-ASPM-kernel7.2.5.md) for the root cause, the `pcie_aspm=off` workaround, and compatibility evidence.

### BCM4350 maintenance changelog

- **2026-09-15:** Documented a `brcmfmac` probe failure on kernel `7.2.5-200.fc44.x86_64` (PCIe ASPM regression, unrelated to the DFS DKMS package) and the `pcie_aspm=off` fix; see [BCM4350-PCIe-ASPM-kernel7.2.5.md](BCM4350-PCIe-ASPM-kernel7.2.5.md).
- **2026-09-10:** Published the corrected source tree with Makefile, DKMS configuration, shared/vendor headers and preserved license notices; attached the source archive, callback patch, successful build log, summary, validation and SHA-256 checksums. Release tag `bcm4350-dfs-1.0-kernel7.2.4-r1` identifies this publication; DKMS `PACKAGE_VERSION="1.0"` remains unchanged. The archive already includes the fix.
- **2026-09-10 (earlier):** Documented the `remain_on_channel` / `rx_addr` correction and explicit target-kernel rebuild procedure. The later publication above supplies the previously pending validation.
- **2026-09-01:** Published the BCM4350 DFS root cause, ISO3166 country-code fallback patch, DKMS packaging, installation, verification and rollback guide.

## BCM43602 on MacBookPro14,2

Board-specific Broadcom BCM43602 NVRAM guidance for the 13-inch 2017 Touch Bar
MacBook Pro.

Validated on:

| Model | Distribution | Device | Result |
|---|---|---|---|
| MacBookPro14,2 | Fedora 44 | BCM43602, PCI ID `14e4:43ba` | 2.4 GHz and 5 GHz working |
| MacBookPro14,2 | Ubuntu / Kubuntu | BCM43602 | Existing installation remains supported |

## Why the complete NVRAM is required

On Fedora 44, a minimal NVRAM file was not sufficient. The working result used
the complete, calibrated board NVRAM, including these required values:

```text
devid=0x43ba
ccode=00
regrev=245
aa2g=7
aa5g=7
txchain=7
rxchain=7
```

These lines are only the identifying values. Keep all other antenna, power,
spur, FEM, PA and calibration parameters from the complete MacBookPro14,2
NVRAM. Do not replace the full board data with the short block above.

## Use the permanent MAC address

The `macaddr` entry must contain the interface's **permanent hardware
address**:

```bash
sudo ethtool -P wlp2s0
```

Use the address printed after `Permanent address:` in the complete NVRAM:

```text
macaddr=<permanent-address-reported-by-ethtool>
```

Do **not** use `cat /sys/class/net/wlp2s0/address` as the source. That value
can be randomized by NetworkManager and can change between connections. The
repository intentionally does not publish the MAC address of a specific
machine as a reusable example.

If the wireless interface has a different name, replace `wlp2s0` in the
commands.

## Install on Fedora

Install `ethtool` if necessary:

```bash
sudo dnf install ethtool iw
```

Create the firmware directory and install the completed NVRAM using the exact
board-specific filename:

```bash
sudo install -d /usr/lib/firmware/brcm
sudo install -m 0644 brcmfmac43602-pcie.Apple\ Inc.-MacBookPro14,2.txt "/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt"
sudo reboot
```

If the firmware lookup on a particular kernel requests the generic name, also
install the same complete file as a fallback:

```bash
sudo cp "/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt" /usr/lib/firmware/brcm/brcmfmac43602-pcie.txt
sudo reboot
```

No `dracut --install` or `install_items` step is required by this
working Fedora procedure.

## Install on Ubuntu or Kubuntu

Use the same complete NVRAM and permanent-MAC rule, then copy it to the same
board-specific path under `/usr/lib/firmware/brcm`. Existing systems that
include firmware in the initramfs may then run:

```bash
sudo update-initramfs -u
sudo reboot
```

## Verify both bands

Confirm that the PHY exposes Band 2, which contains the 5 GHz channels:

```bash
iw phy phy0 channels
```

Then inspect the networks, frequencies and channels reported by
NetworkManager:

```bash
nmcli -f IN-USE,SSID,FREQ,CHAN,RATE,SIGNAL dev wifi list
```

A successful result shows 2.4 GHz networks around 2412-2484 MHz and 5 GHz
networks above 5000 MHz.

For diagnostics:

```bash
sudo dmesg | grep -i brcmfmac
```

A warning that a `clm_blob` was not found is not, by itself, the cause of
missing 5 GHz support: 5 GHz was validated with the complete calibrated NVRAM
and without a CLM blob.
