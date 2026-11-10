# Changelog

## v2.0.1 — 2026-11-10

Wi-Fi 14,1 (DFS) only; every other package is unchanged and carried over
byte-identical from v2.0.0.

Kernel 7.3 changed `cfg80211_ops.mgmt_tx` and `.remain_on_channel`: the
`cookie` argument went from an output pointer (`u64 *`) to an input value
(`u64`). The 2.0-1 source (pinned to upstream v7.1.12, plus the 2026-09
`rx_addr` shim for 7.2) failed to build on 7.3 with
`-Wincompatible-pointer-types` on both callbacks.

- Resynced `wifi-bcm4350/src/` to upstream `brcmfmac` tag `v7.3.3` — same
  chip-ID whitelist one-liner, carried over to the current source instead of
  patched onto an aging snapshot. Removes the now-unneeded `p2p.c`/`p2p.h`
  `LINUX_VERSION_CODE` shims from 2026-09: a fresh upstream snapshot is
  self-consistent with its own `cfg80211` API.
- This is a one-way move, not an added target: the 2.0-2 source builds on
  Linux 7.3 and **no longer builds on Linux 7.2** (verified: compiling it
  against `kernel-devel-7.2.15-300.fc45` reproduces the same
  `-Wincompatible-pointer-types` error, mirrored the other way). Stay on
  2.0-1 while running a 7.2.x kernel.
- `brmcf_use_iso3166_ccode_fallback()`'s BCM4350 case is itself upstream now:
  commit `c56821fb3eeec2a8fbf30086b85fdb836cf4e781`, "wifi: brcmfmac: allow
  ISO3166 fallback for BCM4350", merged into Linux mainline on 2026-10-05 (no
  `Cc: stable`, so expect it in a feature release rather than a 7.3.x
  backport). Once that kernel ships, this package becomes redundant for it.
- No `.deb`: same reason as 2.0-1 — the source is pinned to one upstream
  kernel tag, which Debian/Ubuntu don't ship.

Verified: `dkms build`/`dkms install -k 7.3.3-300.fc45.x86_64` on the
maintainer's own MacBookPro14,1 (exit 0, module signed with the host's DKMS
MOK key); a from-scratch `dnf install` of the built RPM plus a forced
`dkms build` for the same kernel release in a clean Fedora 45 container
(`dkms status` → `built`). Not yet verified: an actual post-reboot Wi-Fi
association on 7.3.3 — the maintainer's machine had not rebooted into it at
publication time.

## v2.0.0 — 2026-10-29

The repository is reorganised around one package per feature.

- New `mbp-cirrus-audio-dkms` 2.0 (.rpm and .deb): built from
  davidjo/snd_hda_macbookpro commit `6c324f6` instead of an older vendored
  copy. Replaces a hand-made `dkms.sh` installation.
- New `brcmfmac-bcm4350-dfs-dkms` 2.0 (.rpm): the BCM4350 DFS driver of the
  MacBookPro14,1 as a package. Before, it had to be copied and built by hand.
  Builds only where a BCM4350 is present.
- New `brcmfmac43602-mbp14-2-nvram` 2.0 (.rpm and .deb): the complete
  MacBookPro14,2 Wi-Fi NVRAM, with the machine's own MAC address filled in on
  installation. The NVRAM file previously in `wifi/` was for another board
  and is gone.
- `mbp-t1-touchbar-dkms` 1.0-4: conflicts with `t1bridge-dkms`; one build
  script; maintainer address fixed. Driver unchanged.
- Touch ID (T1Bridge 0.1.12 port preview.2) and the FaceTime camera
  (0.7.2.git20260929) are unchanged.
- One `build.sh` builds everything in containers; one README with a table of
  which file to download.
- Removed: committed .deb files, Wi-Fi build logs and evidence (still attached
  to the `bcm4350-dfs-1.0-kernel7.2.4-r1` release), `tools/`, duplicated docs.

Component history: [touchbar](touchbar/CHANGELOG.md), [camera](camera/CHANGELOG.md),
[touchid](touchid/CHANGELOG.md). Earlier releases: v1.2.0 (camera, Touch Bar
1.0-3), v1.1.0 (audio 1.0-1, Touch Bar 1.0-2), v1.0.2.
