# BCM4350 Wi-Fi probe failure on kernel 7.2.5 (PCIe ASPM regression)

MacBookPro14,1 with kernel `7.2.5-200.fc44.x86_64` (Fedora 44) failed to bring up Wi-Fi: `brcmfmac` never created a `wlp*` interface. This is a different failure mode from [BCM4350-DFS.md](BCM4350-DFS.md): a probe-time failure at boot, not a regulatory/channel restriction after a successful association.

The previous kernel, `7.2.4-200.fc44.x86_64`, was unaffected; DKMS build and load of `brcmfmac-bcm4350-dfs/1.0` completed normally on both kernels (`dkms status` reported `installed` for both).

## Symptom

```text
brcmfmac: brcmf_chip_recognition: MMIO read failed: 0xffffffff
brcmf_pcie_probe: failed 14e4:43a3
```

## Root cause

This is not a `brcmfmac-bcm4350-dfs` build or DKMS problem:

- `dkms status` reported the module `installed` for `7.2.5-200.fc44.x86_64`.
- PCI enumeration succeeded normally: the device appears in `lspci` at `0000:02:00.0` with BARs assigned correctly.
- The failure occurs inside driver probe, when `brcmfmac` reads chip identification registers over PCIe; the MMIO read returns all-ones (`0xffffffff`), the classic signature of a device that is not actually reachable/powered on the bus at read time.
- Diffing `/boot/config-7.2.4-200.fc44.x86_64` against `/boot/config-7.2.5-200.fc44.x86_64` found no ASPM/PCI-PM-related `CONFIG_*` change (only an `rustc` version bump and an unrelated camera driver module).

This points to a kernel-side PCIe link power-management regression (ASPM / runtime PM) somewhere on the bridge chain leading to the Wi-Fi chip (`00:1c.x -> 04:00.0 -> 05:xx -> 06:00.0 -> 07:00.0 -> 02:00.0`), not a driver defect, firmware/NVRAM problem, or DKMS build issue. The upstream kernel change responsible was not identified; the fix below is a system-level workaround, not a patch to `brcmfmac-bcm4350-dfs`.

## Fix

Disable PCIe ASPM globally via the kernel command line:

```text
pcie_aspm=off
```

**Fedora (BLS, `GRUB_ENABLE_BLSCFG=true`):**

```bash
sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX=")(.*)"$/\1\2 pcie_aspm=off"/' /etc/default/grub
sudo grubby --update-kernel=ALL --args="pcie_aspm=off"
```

The first line makes the parameter apply to future kernel installs (read from `/etc/default/grub`); the second backfills every already-installed BLS entry. Adding it to only one kernel's boot entry (by hand, or with `grubby` but without `--update-kernel=ALL`) does not persist across a `grub2-mkconfig` regeneration or a BLS entry rebuild.

**Ubuntu/Debian (classic GRUB):** add it to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then `sudo update-grub`.

## Verify

```bash
grep -o pcie_aspm=off /proc/cmdline
sudo dmesg | grep -i brcmf_pcie_probe   # should show no "failed" line
ip link show                            # wlp* interface should be UP
```

After rebooting into `7.2.5-200.fc44.x86_64` with `pcie_aspm=off` present in `/proc/cmdline`, `brcmf_pcie_probe` no longer fails and Wi-Fi comes up normally.

## Compatibility evidence

| Kernel | Result |
| --- | --- |
| 7.2.4-200.fc44.x86_64 | Wi-Fi works without `pcie_aspm=off`. |
| 7.2.5-200.fc44.x86_64 | Fails without `pcie_aspm=off` (`brcmf_pcie_probe: failed 14e4:43a3`); confirmed working with it present. |
| Other kernels | Not established by this report. |

This does not establish which upstream kernel change introduced the regression, nor whether it affects kernels other than 7.2.5 on this specific bridge topology. Treat `pcie_aspm=off` as a workaround, not a root-cause fix.

## Maintenance changelog

- **2026-09-15:** Root-caused a `brcmfmac` probe failure on kernel `7.2.5-200.fc44.x86_64` (`brcmf_pcie_probe: failed 14e4:43a3`, MMIO read returning `0xffffffff`) to a PCIe power-management regression, ruled out a DKMS/build cause, and confirmed `pcie_aspm=off` resolves it. Persisted the parameter in `/etc/default/grub` and backfilled all existing BLS kernel entries with `grubby --update-kernel=ALL`.
