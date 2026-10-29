# Changelog

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
