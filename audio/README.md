# Audio: Cirrus CS8409 (MacBookPro14,1 and 14,2)

Package: `mbp-cirrus-audio-dkms`. Makes the internal speakers and microphone
work.

The kernel's own CS8409 driver does not know the Apple amplifiers.
[davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
patches it. The package holds that project at commit `6c324f6` (2026-08-10)
and builds it with DKMS. Each build downloads the sound sources of the running
kernel: from kernel.org on Fedora, or from the `linux-source` package on
Ubuntu.

- Needs Linux 6.17 or newer (Fedora 44/45, Ubuntu 26.04). Debian 13's 6.12
  kernel is not supported.
- Needs network access when it builds, also after each kernel update.
- If you installed the driver by hand with upstream's `dkms.sh`, the package
  replaces that registration.

Check after the reboot:

```bash
dkms status snd_hda_macbookpro
lsmod | grep cs8409
```

Then choose **Analog Stereo Output**, or **Analog Stereo Duplex** for the
microphone too. If the build failed, the log is in
`/var/lib/dkms/snd_hda_macbookpro/2.0/build/make.log`.

Build: `bash audio/build.sh OUTDIR` (or `./build.sh audio`). License: GPL-2.0.
