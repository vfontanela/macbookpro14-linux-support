# Technical summary — brcmfmac-bcm4350-dfs kernel 7.2+ build fix

## Package / source base

- **DKMS package:** `brcmfmac-bcm4350-dfs`, version `1.0` (from `dkms.conf`:
  `BUILT_MODULE_NAME[0]="brcmfmac"`, installed to `/updates`, `AUTOINSTALL="yes"`).
- **Source layout:** the in-tree source at `/usr/src/brcmfmac-bcm4350-dfs-1.0/`
  is a full out-of-tree copy of the Linux `brcmfmac` driver (Broadcom
  BCM4350 chip family), carrying the same file layout as the upstream
  in-kernel driver at `drivers/net/wireless/broadcom/brcm80211/brcmfmac/`,
  including the `bca/`, `cyw/`, `wcc/` vendor-ops subdirectories and the
  `shared-include/` headers. Files carry the standard
  `Copyright (c) 2010 Broadcom Corporation`, ISC-licensed header used
  upstream. There is **no explicit upstream git tag, commit hash, or kernel
  version string recorded anywhere in the source tree or `dkms.conf`** —
  the on-disk file timestamps (2026-09-01) reflect when the package was
  installed on this machine, not an upstream release. Anyone publishing
  this should treat the exact upstream base commit as unknown/unpinned
  unless it's tracked separately outside this machine. The original repository
  documentation reported a `v7.1.12` base; that report is not a verifiable
  upstream commit recorded by this source package.
- This package is *not* stock `brcmfmac` — its distinguishing feature (per
  the user, and per the package name) is a DFS (radar-detection, 5 GHz
  UNII-2/2e channel) support patch on top of the base driver, which is why
  it's carried out-of-tree via DKMS instead of using the in-kernel module.

## Files changed by this fix

Only two files were modified, both under `/usr/src/brcmfmac-bcm4350-dfs-1.0/`:

- `p2p.h` — forward declaration of `brcmf_p2p_remain_on_channel()`
- `p2p.c` — definition of `brcmf_p2p_remain_on_channel()`

No other file in the package needed changes. See
`fix-remain_on_channel-kernel72.patch` for the exact diff (verified to
apply cleanly with `patch -p1` and reproduce the live, currently-installed
source byte-for-byte).

## Why the fix was needed

On the tested kernel `7.2.4-200.fc44.x86_64`, the DKMS build failed with:

```
cfg80211.c:6018:30: error: initialization of 'int (*)(struct wiphy *, struct wireless_dev *,
struct ieee80211_channel *, unsigned int, u64 *, const u8 *)' from incompatible pointer type
'int (*)(struct wiphy *, struct wireless_dev *, struct ieee80211_channel *, unsigned int, u64 *)'
[-Wincompatible-pointer-types]
 6018 |         .remain_on_channel = brcmf_p2p_remain_on_channel,
```

The reported target kernel exposes a changed `remain_on_channel` callback in
`struct cfg80211_ops` (`include/net/cfg80211.h`) to add a new
`const u8 *rx_addr` parameter. The driver's own
`brcmf_p2p_remain_on_channel()` still used the old 5-argument signature, so
the function-pointer assignment in `cfg80211.c` (unmodified, part of the
package, not touched by this fix) stopped type-checking.

## The fix

`brcmf_p2p_remain_on_channel()`'s signature in both `p2p.h` and `p2p.c` is
now gated on `LINUX_VERSION_CODE`:

```c
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)
int brcmf_p2p_remain_on_channel(..., u64 *cookie, const u8 *rx_addr);
#else
int brcmf_p2p_remain_on_channel(..., u64 *cookie);
#endif
```

with the new `rx_addr` parameter marked `(void)rx_addr;` inside the
function body on the new-kernel branch, since this driver's
remain-on-channel implementation doesn't use it. `cfg80211.c` needed no
change — the struct field assignment matches whichever prototype is active
for the kernel being built against.

### Version-gate condition and its limitations

The cutoff `LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)` was chosen
empirically, not from an upstream commit reference:

- Confirmed **building and working, unmodified**, on `7.1.12-200.fc44.x86_64`
  and `7.1.13-200.fc44.x86_64` (old 5-argument signature).
- Confirmed **failing to build, unmodified**, on `7.2.4-200.fc44.x86_64`,
  and confirmed **building and working after the fix** on that same
  version (new 6-argument signature).

No kernel between 7.1.13 and 7.2.4 was available to test, so the exact
point release where the ABI actually changed is not pinned — `7.2.0` was
picked as a reasonable boundary given the only two data points available.

**Limitations:**

- If upstream backported this `cfg80211_ops.remain_on_channel` ABI change
  to an earlier stable point release (e.g. into a 7.1.x stable branch), the
  guard would need lowering — this hasn't been checked against every
  intermediate stable tag.
- If a future kernel changes the signature again, this same
  `-Wincompatible-pointer-types` failure mode on a `cfg80211_ops` field is
  the pattern to look for, and the same version-gated approach likely
  applies, but the exact new cutoff would need to be re-derived the same
  empirical way (bisecting on the actual failing/working kernel versions
  available).
- The gate is on kernel version only; it does not detect the ABI directly
  (e.g. via a feature-test macro), so it will silently produce the wrong
  prototype if a distro backports the new cfg80211 ABI onto an
  older-numbered kernel package.

## Kernels actually tested on this machine

| Kernel | Fix applied? | Build result | Confirmed via |
|---|---|---|---|
| `7.1.12-200.fc44.x86_64` | No (pre-existing, unmodified) | OK | `dkms status` |
| `7.1.13-200.fc44.x86_64` | No (pre-existing, unmodified) | OK | `dkms status` |
| `7.2.4-200.fc44.x86_64` | Yes | OK (exit code 0) | `make.log`, `dkms status`, live boot + `iw dev wlp2s0 link` on a DFS channel (see `VALIDATION.md`) |

## Publication verification and versioning

Release tag: `bcm4350-dfs-1.0-kernel7.2.4-r1`. This identifies the source
publication revision; DKMS `PACKAGE_VERSION="1.0"` remains unchanged.
The source archive already includes the callback fix; do not apply the
patch again to the released tree. The patch is for the pre-fix package.

A separate working copy was inspected without building or installing the
driver. All 69 source/package files are present; quoted local includes
resolve, including shared-include and bca/cyw/wcc headers. Reversing and
reapplying the patch reproduced p2p.c and p2p.h byte-for-byte. The BCM4350
country-code fallback is present. Source bytes and license notices were
preserved, as were the original source archive and build log.

`modinfo` resolves an on-disk module file, not necessarily the in-memory
binary. Matching vermagic does not guarantee full compatibility. The
recorded post-reboot association was 5580 MHz / DFS channel 116; see
`VALIDATION.md` for evidence and its limits.
