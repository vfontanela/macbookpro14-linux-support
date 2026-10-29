# Wi-Fi: BCM4350 DFS channels (MacBookPro14,1)

Package: `brcmfmac-bcm4350-dfs-dkms` (Fedora). Lets the BCM4350 (`14e4:43a3`)
use the 5 GHz DFS channels 100-144. 2.4 GHz and the other 5 GHz channels
already work without it.

**Why.** `brcmfmac` only sends the regulatory country to the firmware for the
chips listed in `brmcf_use_iso3166_ccode_fallback()`. BCM4350 was missing, so
the firmware kept its boot locale, and the DFS channels stayed hidden even
after `iw reg set`. The package builds `brcmfmac` with one added line:

```diff
     case BRCM_CC_4345_CHIP_ID:
+    case BRCM_CC_4350_CHIP_ID:
     case BRCM_CC_4356_CHIP_ID:
```

`src/` is a copy of the kernel's `brcmfmac` driver (ISC license), with that
line and the 7.2 `remain_on_channel` signature. The upstream base commit was
not recorded. The package only builds on a machine that has a BCM4350, and
only on Linux 7.2. When the build fails, the kernel's own driver stays in
use: Wi-Fi works, just without DFS.

Check after the reboot:

```bash
modinfo -F filename brcmfmac          # a path under /updates/ or /extra/
iw dev wlp2s0 link                    # e.g. 5580 MHz = channel 116
```

**Kernel 7.2.5 and later:** if Wi-Fi disappears completely
(`brcmf_pcie_probe: failed 14e4:43a3` in `journalctl -k`), it is a PCIe
power-management regression, not this package. Booting with `pcie_aspm=off`
fixes it:

```bash
sudo grubby --update-kernel=ALL --args=pcie_aspm=off
```

Build: `bash wifi-bcm4350/build.sh OUTDIR`.
