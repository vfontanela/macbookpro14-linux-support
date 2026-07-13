# BCM43602 Wi-Fi Fix for MacBookPro14,2 (2017)

Configuration file for enabling full Broadcom BCM43602 functionality on the MacBook Pro 13" 2017 (MacBookPro14,2) under modern Linux distributions.

## Before installing

Edit the file:

```bash
sudo nano "/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt"
```

Replace

```text
macaddr=XX:XX:XX:XX:XX:XX
```

with your wireless interface MAC address.

You can obtain it with:

```bash
cat /sys/class/net/wlp2s0/address
```

or

```bash
ip link show wlp2s0
```

Then rebuild the initramfs:

```bash
sudo update-initramfs -u
sudo reboot
```

## Problem

After a fresh installation of Ubuntu, Kubuntu or other Linux distributions, the Broadcom BCM43602 driver (`brcmfmac`) usually loads successfully, but without a board-specific NVRAM configuration.

Typical kernel messages include:

```
Direct firmware load for brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.bin failed
Direct firmware load for brcm/brcmfmac43602-pcie.clm_blob failed
```

As a result, the wireless interface may exhibit:

- inability to discover 5 GHz networks
- unstable signal
- poor roaming
- reduced transmit power
- intermittent connection failures

## Solution

This repository provides the missing board-specific NVRAM configuration file:

```
brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt
```

When placed in:

```
/usr/lib/firmware/brcm/
```

the `brcmfmac` driver automatically loads the proper board parameters during boot.
## Before installing

Edit the file:

```bash
sudo nano "/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt"
```

Replace

```text
macaddr=XX:XX:XX:XX:XX:XX
```

with your wireless interface MAC address.

You can obtain it with:

```bash
cat /sys/class/net/wlp2s0/address
```

or

```bash
ip link show wlp2s0
```

Then rebuild the initramfs:

```bash
sudo update-initramfs -u
sudo reboot
```
## Installation

Copy the file:

```bash
sudo cp brcmfmac43602-pcie.Apple\ Inc.-MacBookPro14,2.txt \
/usr/lib/firmware/brcm/
```

Then rebuild the initramfs:

```bash
sudo update-initramfs -u
```

Reboot.

## Verification

After reboot:

```bash
sudo dmesg | grep brcmfmac
```

The firmware should initialize normally.

You should also be able to detect and connect to 5 GHz networks.

## Tested on

- MacBook Pro 13" 2017 Touch Bar
- Model: MacBookPro14,2
- Broadcom BCM43602 (PCI ID 14e4:43ba)
- Kubuntu 26.04 LTS
- Linux kernel 7.0.x

## Credits

The configuration values originate from community work around the Broadcom BCM43602 firmware. This repository simply packages and documents the configuration for modern Linux installations on the MacBookPro14,2.

## License

The configuration file contains board parameters intended for Broadcom firmware and is redistributed for compatibility purposes.
