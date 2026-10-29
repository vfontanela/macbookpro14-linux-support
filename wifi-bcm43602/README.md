# Wi-Fi: BCM43602 NVRAM (MacBookPro14,2)

Package: `brcmfmac43602-mbp14-2-nvram`. Makes the BCM43602 (`14e4:43ba`) work
on 2.4 and 5 GHz.

`brcmfmac` needs a board NVRAM file for this chip, and Linux does not ship one
for the MacBookPro14,2. A short file is not enough. The package carries the
complete calibrated NVRAM of a MacBookPro14,2, without its MAC address. During
installation it:

1. reads the machine's permanent MAC address (`ethtool -P`);
2. writes `/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt`
   with that address;
3. saves an existing file there to `/var/lib/brcmfmac43602-mbp14-2-nvram/`,
   and puts it back on removal.

If the Wi-Fi interface does not exist yet, the file is written without a MAC
address and the chip uses its own. Run
`sudo /usr/libexec/brcmfmac43602-mbp14-2-nvram/setup install` after the reboot
to fill it in. It does nothing on other models. The written file starts with a marker line;
delete that line if you edit the file and want to keep your changes.

Check after the reboot:

```bash
iw phy phy0 channels | grep -c MHz
nmcli -f SSID,FREQ,CHAN dev wifi list      # 5 GHz networks above 5000 MHz
```

The calibration data comes from one MacBookPro14,2. It has worked there on
Fedora 44 and 45. A missing `clm_blob` warning in the log is harmless.

Build: `bash wifi-bcm43602/build.sh OUTDIR`.
