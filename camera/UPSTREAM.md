# Provenance and licensing

Driver: https://github.com/patjak/facetimehd
Pinned commit: `1f52306c6c958e7b1d8c3fd20236ed43b8efc8a0` (2026-09-29).
Base release: 0.7.2; this snapshot is 30 commits after that tag.
Original authors include Patrik Jakobsson and Sven Schnelle; original copyright
notices and complete GPLv2 license are preserved in `src/`.

Firmware extraction tool: https://github.com/patjak/facetimehd-firmware
Pinned commit: `60ee21228d9ca00a7bd84fdaefaff00a81f1db91` (2026-08-19).
The tool is GPL-2.0-only; its complete license is in `firmware-tool/LICENSE`.
Its current default extracts firmware 5.60.0 and eleven sensor calibration
files from Apple's macOS 10.12.6 combo update, using roughly 18 MB of HTTP ranges.
The upstream hashes and extraction offsets are retained unchanged.

Local changes to the driver tree: ONLY `dkms.conf`, setting a unique snapshot
version, kernel-specific make invocations, and no `MODULES_CONF` blacklist.
Driver C/header files and Makefile are byte-identical to the pinned upstream.
No legacy V4L2/kernel patches have been added: this snapshot compiles as is
against the Fedora kernel headers tested here.

Local changes to the firmware tool: strict error handling; HTTPS-only downloads;
HTTP 206 and exact range-size validation; bounded downloads; an explicit output
directory for unprivileged extraction validation; quoted installation paths.
The emitted firmware and sensor files are verified against upstream SHA256 values
before installation. The rest of the firmware extraction logic is preserved.

The GPL license covers the driver and extraction tools, not the proprietary
Apple firmware they extract. This project grants no firmware redistribution
permission, and includes no Apple binary, firmware.bin or calibration .dat file
in its repository/package deliverables. Download/extraction happens only when
the user explicitly runs the firmware command on their own computer, subject
to the applicable Apple terms. Existing firmware can be retained instead.
