ifneq ($(KERNELRELEASE),)
# kbuild part of makefile

obj-m := apple-ib-tb.o apple-ib-als.o apple-ibridge.o

else
# normal makefile
KDIR ?= /lib/modules/`uname -r`/build

all:
	$(MAKE) -C $(KDIR) M=$$PWD modules

clean:
	$(MAKE) -C $(KDIR) M=$$PWD clean

install:
	$(MAKE) -C $(KDIR) M=$$PWD modules_install
	depmod

.PHONY: all clean

endif
