# DKMS build for a patched brcmfmac: adds BRCM_CC_4350_CHIP_ID to the
# ISO3166 ccode fallback whitelist in brmcf_use_iso3166_ccode_fallback()
# (drivers/net/wireless/broadcom/brcm80211/brcmfmac/cfg80211.c upstream).
# Without this, brcmf_translate_country_code() returns -EINVAL for the
# BCM4350 (PCIe id 0x43a3) before ever writing the "country" iovar to
# firmware, so regulatory-hint changes (iw reg set) never reach the chip
# and DFS channels 100-144 stay excluded from scan regardless of locale.
#
# Object list mirrors this system's kernel .config:
#   CONFIG_BRCMFMAC_PROTO_BCDC=y CONFIG_BRCMFMAC_PROTO_MSGBUF=y
#   CONFIG_BRCMFMAC_SDIO=y CONFIG_BRCMFMAC_USB=y CONFIG_BRCMFMAC_PCIE=y
#   CONFIG_DMI=y CONFIG_ACPI=y
#   CONFIG_BRCMDBG not set, CONFIG_BRCM_TRACING not set, CONFIG_OF not set
# Re-check /boot/config-$(uname -r) after a major Fedora kernel bump and
# update this list (and re-download upstream sources) if it drifts.

ccflags-y += -I $(src) -I $(src)/shared-include

obj-m += brcmfmac.o
brcmfmac-objs := \
	cfg80211.o \
	chip.o \
	fwil.o \
	fweh.o \
	p2p.o \
	proto.o \
	common.o \
	core.o \
	firmware.o \
	fwvid.o \
	feature.o \
	btcoex.o \
	vendor.o \
	pno.o \
	xtlv.o \
	bcdc.o \
	fwsignal.o \
	commonring.o \
	flowring.o \
	msgbuf.o \
	sdio.o \
	bcmsdh.o \
	usb.o \
	pcie.o \
	dmi.o \
	acpi.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
