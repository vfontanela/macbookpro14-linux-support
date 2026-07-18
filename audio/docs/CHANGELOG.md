# Changelog

## 1.0-1

- Initial DKMS packaging of davidjo/snd_hda_macbookpro (Cirrus CS8409
  HDA audio driver). Full upstream source vendored into `src/` so the
  package has no runtime dependency on the upstream GitHub repo.
- `dkms.conf` uses the community fix from upstream issue #164
  (custom `MAKE` with `CFLAGS_MODULE` overrides) needed to compile
  cleanly on GCC 14+ / kernel 6.17+; verified to also apply to kernel
  7.x, since `install.cirrus.driver.sh` already branches on
  `major_version >= 7` for its Cirrus codec patches.
- `install.cirrus.driver.sh` patched (diff clearly marked inline) to
  cache the downloaded + patched sound/hda source tree per kernel
  version under `/var/cache/mbp-cirrus-audio-dkms/hda-src/`. Ubuntu
  kernel ABI bumps share the same kernel_version, so routine kernel
  updates rebuild fully offline; only a genuine new upstream kernel
  version still needs a fresh download.
- `postinst` proactively checks for the matching
  `linux-source-<version>` package before attempting the build (this
  driver's `PRE_BUILD` step needs kernel *source*, not just headers),
  and prints the exact fix instead of failing deep inside DKMS with a
  confusing error.
- Goal: replaces the previous manual workflow (`install.cirrus.driver.sh`
  + `dkms.sh` re-run by hand after every kernel update) with standard
  DKMS autoinstall via `/etc/kernel/postinst.d/dkms` - same mechanism
  used by the `mbp-t1-touchbar-dkms` package.
