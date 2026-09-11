# Validation — brcmfmac-bcm4350-dfs on kernel 7.2.4-200.fc44.x86_64

All command output below was captured directly on the affected machine on
2026-09-10, after the fix in `fix-remain_on_channel-kernel72.patch` was
applied, rebuilt, and installed via DKMS for kernel `7.2.4-200.fc44.x86_64`,
and after a full reboot into that kernel. MAC addresses, SSID and BSSID have
been redacted (`<REDACTED-*>`) — none affect the technical conclusions below.

## User-reported confirmation (not independently re-verified by these checks)

The user reported, in conversation, that the system had already been
rebooted into the new kernel and that Wi-Fi was working normally after the
fix. That statement is the user's own account and predates the command runs
below — it is reproduced here as-reported, not as a tool-verified fact. The
command output in the next section is the independent, tool-run verification
performed at documentation time, on the same running system.

## Recorded verification (supplied tool-run output, 2026-09-10)

### `uname -r`

```
7.2.4-200.fc44.x86_64
```

Confirms the system is actually running the previously-broken kernel version.

### `dkms status`

```
brcmfmac-bcm4350-dfs/1.0, 7.1.12-200.fc44.x86_64, x86_64: installed (Original modules exist)
brcmfmac-bcm4350-dfs/1.0, 7.1.13-200.fc44.x86_64, x86_64: installed (Original modules exist)
brcmfmac-bcm4350-dfs/1.0, 7.2.4-200.fc44.x86_64, x86_64: installed (Original modules exist)
snd_hda_macbookpro/0.1, 7.1.12-200.fc44.x86_64, x86_64: installed (Original modules exist)
snd_hda_macbookpro/0.1, 7.1.13-200.fc44.x86_64, x86_64: installed (Original modules exist)
snd_hda_macbookpro/0.1, 7.2.4-200.fc44.x86_64, x86_64: installed (Original modules exist)
```

`brcmfmac-bcm4350-dfs/1.0` shows `installed` for all three tracked kernels,
including `7.2.4-200.fc44.x86_64` — the kernel that previously failed to
build.

### `modinfo -F filename brcmfmac`

```
/lib/modules/7.2.4-200.fc44.x86_64/extra/brcmfmac.ko.xz
```

This is the module file resolved by modinfo for the running kernel. It does
not, by itself, identify the exact binary already loaded in memory.

### `modinfo -F vermagic brcmfmac`

```
7.2.4-200.fc44.x86_64 SMP preempt mod_unload
```

The vermagic release string matches the running kernel. This is a useful
consistency check, not a guarantee of full ABI or behavioral compatibility.

### `iw dev wlp2s0 link`

```
Connected to <REDACTED-BSSID> (on wlp2s0)
	SSID: <REDACTED-SSID>
	freq: 5580.0
	RX: 544964209 bytes (403738 packets)
	TX: 24793337 bytes (95139 packets)
	signal: -53 dBm
	rx bitrate: 400.0 MBit/s
	tx bitrate: 81.0 MBit/s
	bss flags: short-preamble
	dtim period: 1
	beacon int: 100
```

**Frequency 5580 MHz corresponds to channel 116**, a DFS channel in the
5 GHz UNII-2e band. This records a working association on that channel after
the reported reboot. It does not independently fingerprint the loaded
binary, exercise every DFS behavior, or establish regulatory certification.

### `lsmod | grep brcmfmac` (supplementary — not in the original request, added for completeness)

```
brcmfmac_wcc           12288  0
brcmfmac              561152  1 brcmfmac_wcc
brcmutil               28672  1 brcmfmac
cfg80211             1691648  1 brcmfmac
mmc_core              327680  1 brcmfmac
```

Records that modules named `brcmfmac` and `brcmfmac_wcc` are loaded and
shows their dependency/reference counts. Those counts do not independently
identify the loaded file or prove which code path carried traffic.

## Summary

The supplied records show a successful build (exit code 0; see
`make-7.2.4-200.fc44.x86_64.log`), boot into `7.2.4-200.fc44.x86_64`,
DKMS installation for that kernel, loaded module names, and a working
association at 5580 MHz / DFS channel 116. This supports the reported
post-fix runtime result for this system. It does not independently identify
the exact in-memory binary or guarantee compatibility with other kernels.

These are historical evidence supplied for publication; the publication
process did not rebuild, reinstall, reload, or otherwise alter the local
driver. SSID and BSSID remain redacted.
