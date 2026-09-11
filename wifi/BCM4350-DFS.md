# BCM4350 DFS channels on MacBookPro14,1

MacBookPro14,1 (A1708, without Touch Bar) uses a Broadcom BCM4350 `[14e4:43a3]`. On Fedora 44 with kernel 7.1.12, 2.4 GHz and non-DFS 5 GHz worked, but access points on DFS UNII-2e channels 100-144 were invisible. The fix was validated against channel 116 (5580 MHz).

The fix is a one-line `brcmfmac` patch packaged as `brcmfmac-bcm4350-dfs/1.0` with DKMS. It does not modify firmware, NVRAM or third-party regulatory blobs.

## Root cause

`cfg80211` exposed channel 116 and did not mark it disabled. The failure was inside `brcmfmac`: with no explicit country map, `brcmf_translate_country_code()` only allows chips listed by `brmcf_use_iso3166_ccode_fallback()`. BCM4350 was missing even though `BRCM_CC_4350_CHIP_ID` exists and the adjacent 4345 and 4356 chips are present.

The translation returned `-EINVAL`; the regulatory notifier then returned without writing the `country` iovar to firmware. The boot locale remained active and UNII-2e stayed unavailable. This is silent when `CONFIG_BRCMDBG` is disabled, because the caller emits no error and the relevant trace is compiled out. Thus `iw reg set` appeared to work but never changed firmware state.

`country 99: DFS-UNSET`, missing `clm_blob`, scan type and NVRAM `ccode`/`regrev` changes were ruled out. BCM4350 firmware already contains its country table; do not install a CLM blob from another chipset.

## Patch

Apply this to `drivers/net/wireless/broadcom/brcm80211/brcmfmac/cfg80211.c` from the source matching the target kernel:

```diff
     switch (drvr->bus_if->chip) {
     case BRCM_CC_43430_CHIP_ID:
     case BRCM_CC_4345_CHIP_ID:
+    case BRCM_CC_4350_CHIP_ID:
     case BRCM_CC_4356_CHIP_ID:
     case BRCM_CC_43602_CHIP_ID:
             return true;
```

The patched path uses the requested ISO3166 alpha-2 country code with revision 0, writes the firmware `country` iovar and rebuilds the wiphy bands.

## DKMS package

Place the matching, patched `brcmfmac` sources under `/usr/src/brcmfmac-bcm4350-dfs-1.0/`, including shared `brcm80211` headers and the `wcc`, `cyw` and `bca` `vops.h` headers. The validated build used upstream tag `v7.1.12` and mirrored the Fedora kernel configuration for BCDC, MSGBUF, SDIO, USB, PCIe, DMI and ACPI.

`dkms.conf`:

```ini
PACKAGE_NAME="brcmfmac-bcm4350-dfs"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="brcmfmac"
DEST_MODULE_LOCATION[0]="/updates"
MAKE[0]="make -C /lib/modules/${kernelver}/build M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build modules KDIR=/lib/modules/${kernelver}/build"
CLEAN="make -C /lib/modules/${kernelver}/build M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build clean"
AUTOINSTALL="yes"
REMAKE_INITRD="no"
```

Validated out-of-tree `Makefile`:

```makefile
ccflags-y += -I $(src) -I $(src)/shared-include

obj-m += brcmfmac.o
brcmfmac-objs := \
	cfg80211.o chip.o fwil.o fweh.o p2p.o proto.o common.o core.o \
	firmware.o fwvid.o feature.o btcoex.o vendor.o pno.o xtlv.o \
	bcdc.o fwsignal.o commonring.o flowring.o msgbuf.o \
	sdio.o bcmsdh.o usb.o pcie.o dmi.o acpi.o

KDIR ?= /lib/modules/$(shell uname -r)/build
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
```

## Install

```bash
sudo dnf install dkms gcc make kernel-devel-$(uname -r) kernel-headers
sudo dkms add -m brcmfmac-bcm4350-dfs -v 1.0
sudo dkms build -m brcmfmac-bcm4350-dfs -v 1.0
sudo dkms install -m brcmfmac-bcm4350-dfs -v 1.0
sudo depmod -a
sudo reboot
```

The validated installation placed `brcmfmac.ko.xz` under `/lib/modules/$(uname -r)/extra/`, ahead of the in-tree module in normal `depmod` resolution.

## Verify

```bash
dkms status
modinfo brcmfmac | grep filename
sudo iw dev wlp2s0 scan freq 5580 passive
iw dev wlp2s0 link
```

Expected output includes `brcmfmac-bcm4350-dfs/1.0`, a module path under `/extra/` (or the distribution's DKMS updates directory), and the target AP at 5580 MHz. In `iw`, `passive` must be the final argument. Replace `wlp2s0` if necessary.

## Roll back

```bash
sudo dkms remove brcmfmac-bcm4350-dfs/1.0 --all
sudo depmod -a
sudo modprobe -r brcmfmac_wcc brcmfmac
sudo modprobe brcmfmac
```

This removes the DKMS module and restores the original in-tree `brcmfmac`. Reload from a local console if Wi-Fi is in use, or reboot after removal.

## Kernel updates

This DKMS package vendors kernel driver sources. After a major update, refresh the source tree and shared headers from the matching upstream tag and reconcile the object list with `/boot/config-$(uname -r)` if the build fails. Sources copied from v7.1.12 are not guaranteed to remain compatible with every future kernel.


## Kernel 7.2 compatibility update (2026-09-10)

The local maintenance report records a build failure on Fedora kernel `7.2.4-200.fc44.x86_64`: `cfg80211_ops.remain_on_channel` expects an additional `const u8 *rx_addr` argument, while the vendored `brcmf_p2p_remain_on_channel()` has the older signature. The diagnostic is `-Wincompatible-pointer-types` at the callback assignment in `cfg80211.c`. The accompanying `pahole` version warning is not the failing diagnostic.

The correction reported as applied locally by Claude Code retains the `v7.1.12` source base and the BCM4350 country-code fallback patch. It adapts the declaration in `p2p.h` and definition in `p2p.c`; the callback assignment in `cfg80211.c` stays unchanged.

Add `#include <linux/version.h>` to `p2p.h`, then use this declaration:

```c
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)
int brcmf_p2p_remain_on_channel(struct wiphy *wiphy, struct wireless_dev *wdev,
                                struct ieee80211_channel *channel,
                                unsigned int duration, u64 *cookie,
                                const u8 *rx_addr);
#else
int brcmf_p2p_remain_on_channel(struct wiphy *wiphy, struct wireless_dev *wdev,
                                struct ieee80211_channel *channel,
                                unsigned int duration, u64 *cookie);
#endif
```

Apply the same conditional signatures to the definition in `p2p.c` (without the trailing semicolons), keeping the existing function body. After its local variable declarations, add:

```c
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)
    (void)rx_addr;
#endif
```

This implementation does not use `rx_addr`. The version guard is the cutoff chosen in the maintenance report: the original package worked on 7.1.12 and 7.1.13 and failed on 7.2.4. It is not proof of the exact upstream introduction point or a guarantee for every 7.2+ kernel. Distribution backports may require checking the actual `include/net/cfg80211.h` callback signature and adjusting the guard.

### Rebuild and verify the target kernel

After updating the persistent sources in `/usr/src/brcmfmac-bcm4350-dfs-1.0/`, install development files matching the target kernel and rebuild it explicitly. Using `uname -r` before reboot would select the currently running kernel instead.

```bash
kernel_target=7.2.4-200.fc44.x86_64
sudo dnf install "kernel-devel-${kernel_target}"
# Remove an existing build/install for this target, if present in dkms status.
sudo dkms remove brcmfmac-bcm4350-dfs/1.0 -k "$kernel_target"
sudo dkms build brcmfmac-bcm4350-dfs/1.0 -k "$kernel_target"
sudo dkms install brcmfmac-bcm4350-dfs/1.0 -k "$kernel_target"
dkms status
modinfo -k "$kernel_target" -F filename brcmfmac
```

Confirm `installed` for the target kernel and a DKMS module path. After booting that kernel, record `uname -r`, `modinfo -F filename brcmfmac`, `iw dev wlp2s0 link`, and a passive scan on the locally permitted target frequency. Module reloads interrupt Wi-Fi; perform them from a local console. A build/install result alone does not establish runtime or DFS connectivity.

### Compatibility evidence

| Kernel | Evidence available |
| --- | --- |
| 7.1.12 (Fedora 44) | Original DFS patch built, loaded through modprobe, and connected on channel 116 / 5580 MHz. |
| 7.1.13 | Original package reported working in the compatibility write-up. |
| 7.2.4-200.fc44.x86_64 | Original callback build failure captured; signature correction reported applied locally. Post-fix build/install and runtime logs have not been included in this repository. |
| Other kernels | Not established by these reports; inspect headers and validate build plus runtime. |

This repository currently documents the BCM4350 DKMS procedure; the complete BCM4350 source tree and a distributable package are not present under `wifi/`. This update records the local correction and does not publish a new driver binary or change DKMS package version `1.0`.
