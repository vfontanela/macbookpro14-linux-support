# T1 vs T2 — why this matters

Apple shipped two very different co-processors behind "the Touch Bar",
and Linux driver support for them is unrelated.

## T1 (2016 / 2017 Touch Bar MacBook Pros)

- Chip: Apple T1 ("iBridge"), an ARM-based co-processor separate from
  the main Intel CPU.
- Presents itself to the host as a **USB device** (`05ac:8600`) with
  several HID interfaces (Touch Bar, ALS, sometimes Touch ID as a
  distinct interface not covered here).
- Models: MacBookPro13,2 / 13,3 (2016), MacBookPro14,2 / 14,3 (2017).
- Linux support: **out-of-tree only**. No mainline driver exists for
  the T1 iBridge as of kernel 7.x. This repo packages the community
  driver stack (`apple-ibridge`, `apple-ib-tb`, `apple-ib-als`).

## T2 (2018+ Touch Bar MacBook Pros, iMac Pro, etc.)

- Chip: Apple T2, a much more capable SoC that also handles the SSD
  controller, secure boot, image signal processor, and audio, in
  addition to the Touch Bar.
- Presents the Touch Bar over a **SPI** bus, not USB.
- Linux support: increasingly mainlined. Since roughly Linux 6.15-6.17,
  the kernel gained `hid-appletb-kbd`, `hid-appletb-bl`, and
  `appletbdrm` for native Touch Bar support on T2 Macs. Other T2
  subsystems (audio, SSD) have their own separate, still-evolving
  support via the [t2linux](https://wiki.t2linux.org/) project.

## Bottom line

| | T1 | T2 |
|---|---|---|
| Bus | USB | SPI |
| Years | 2016-2017 | 2018+ |
| Driver | out-of-tree (this repo) | increasingly in-tree |
| Use this package? | Yes | **No** |

If `lsusb` on your machine shows `05ac:8600 Apple, Inc. iBridge`,
you have a T1 and this package applies to you. If it doesn't show
that device at all, you likely have a T2 Mac and should look at
mainline kernel support or the t2linux project instead.
