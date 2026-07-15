%global modname mbp-t1-touchbar
%global modver 0.3

# Fallback definitions in case systemd-rpm-macros isn't installed on the
# build host. On real Fedora these are already defined and this is a no-op.
%{!?_unitdir: %global _unitdir /usr/lib/systemd/system}
%{!?_udevrulesdir: %global _udevrulesdir /usr/lib/udev/rules.d}

Name:           mbp-t1-touchbar-dkms
Version:        1.0
Release:        2%{?dist}
Summary:        T1 iBridge / Touch Bar driver (DKMS) for MacBook Pro 2016/2017

License:        GPLv2
URL:            https://github.com/parport0/mbp-t1-touchbar-driver
Source0:        %{modname}-%{modver}.tar.gz

BuildArch:      noarch
Requires:       dkms >= 2.2.0.3
Requires:       kmod
Requires:       usbutils
Requires:       systemd
Requires:       systemd-udev
Requires(post): dkms
Requires(preun): dkms

%description
Out-of-tree DKMS package providing the apple-ibridge, apple-ib-tb and
apple-ib-als kernel modules needed to activate the Touch Bar, ambient
light sensor and iBridge USB hub on Intel MacBook Pro models with the
T1 co-processor (MacBookPro13,2 / 13,3 / 14,2 / 14,3 - late 2016 and
mid 2017, both 13" and 15").

This is NOT for T2-equipped MacBooks (2018+), which are increasingly
covered by in-tree drivers (hid-appletb-kbd, hid-appletb-bl,
appletbdrm) since Linux 6.15-6.17. T1 support remains out-of-tree.

Source: import of Ronald Tschalar's original T1 driver, updated for
modern kernels by parport0 (github.com/parport0/mbp-t1-touchbar-driver).
This package adds DKMS packaging plus a systemd service and udev rule
that automate the USB unbind/reprobe dance the driver needs to bind
correctly (including after resume from suspend).

Because this ships as DKMS source, the kernel module is actually
compiled on your machine against your running kernel's headers when
the package is installed - install kernel-devel for your kernel first.

%prep
%setup -q -n %{modname}-%{modver}

%build
# nothing to build here - DKMS compiles the module on the target
# machine, against whichever kernel is running, via %post.

%install
rm -rf %{buildroot}

# kernel module source, laid out for DKMS
install -d %{buildroot}%{_usrsrc}/%{modname}-%{modver}
cp -a src/*.c %{buildroot}%{_usrsrc}/%{modname}-%{modver}/
cp -a src/linux %{buildroot}%{_usrsrc}/%{modname}-%{modver}/
cp -a src/Makefile %{buildroot}%{_usrsrc}/%{modname}-%{modver}/
cp -a src/dkms.conf %{buildroot}%{_usrsrc}/%{modname}-%{modver}/

# runtime automation
install -d %{buildroot}%{_libexecdir}/%{modname}
install -m 0755 scripts/bind-touchbar.sh %{buildroot}%{_libexecdir}/%{modname}/bind-touchbar.sh

install -d %{buildroot}%{_unitdir}
install -m 0644 systemd/mbp-t1-touchbar-bind.service %{buildroot}%{_unitdir}/

install -d %{buildroot}%{_udevrulesdir}
install -m 0644 udev/99-mbp-t1-touchbar.rules %{buildroot}%{_udevrulesdir}/

install -d %{buildroot}%{_sysconfdir}/modprobe.d
install -m 0644 modprobe.d/mbp-t1-touchbar.conf %{buildroot}%{_sysconfdir}/modprobe.d/

install -d %{buildroot}%{_sysconfdir}/modules-load.d
install -m 0644 modules-load.d/mbp-t1-touchbar.conf %{buildroot}%{_sysconfdir}/modules-load.d/

%post
# (re)register the source with dkms, dropping any stale registration
if dkms status -m %{modname} -v %{modver} 2>/dev/null | grep -q %{modver}; then
    dkms remove -m %{modname} -v %{modver} --all >/dev/null 2>&1 || true
fi
dkms add -m %{modname} -v %{modver}

KVER="$(uname -r)"
if [ -d "/lib/modules/$KVER/build" ]; then
    echo "%{name}: building kernel module for $KVER..."
    if dkms build -m %{modname} -v %{modver} -k "$KVER" && \
       dkms install -m %{modname} -v %{modver} -k "$KVER" --force; then
        echo "%{name}: module built and installed for $KVER."
    else
        echo "%{name}: WARNING - build/install failed for $KVER."
        echo "  See /var/lib/dkms/%{modname}/%{modver}/build/make.log for details."
    fi
else
    cat <<EOF
%{name}: WARNING - no kernel headers found for $KVER
  (/lib/modules/$KVER/build is missing).
  Install kernel-devel for your kernel, then run:
    sudo dkms install -m %{modname} -v %{modver} -k $KVER
EOF
fi

systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now mbp-t1-touchbar-bind.service >/dev/null 2>&1 || true
udevadm control --reload-rules >/dev/null 2>&1 || true
udevadm trigger >/dev/null 2>&1 || true

cat <<EOF

%{name} installed.
Check with:  lsusb -t | grep 05ac:8600
Logs with:   journalctl -u mbp-t1-touchbar-bind.service
If the Touch Bar stays blank after a first boot, try rebooting once more.
EOF

%preun
if [ "$1" -eq 0 ]; then
    # full uninstall, not just an upgrade
    systemctl --no-reload disable --now mbp-t1-touchbar-bind.service >/dev/null 2>&1 || true
    dkms remove -m %{modname} -v %{modver} --all >/dev/null 2>&1 || true
fi

%postun
systemctl daemon-reload >/dev/null 2>&1 || true
if [ "$1" -ge 1 ]; then
    # package upgrade, not full removal: restart the service on the new version
    systemctl try-restart mbp-t1-touchbar-bind.service >/dev/null 2>&1 || true
fi

%files
%license LICENSE
%doc README.md docs/T1_VS_T2.md docs/TROUBLESHOOTING.md docs/CHANGELOG.md
%{_usrsrc}/%{modname}-%{modver}/
%{_libexecdir}/%{modname}/bind-touchbar.sh
%{_unitdir}/mbp-t1-touchbar-bind.service
%{_udevrulesdir}/99-mbp-t1-touchbar.rules
%config(noreplace) %{_sysconfdir}/modprobe.d/mbp-t1-touchbar.conf
%config(noreplace) %{_sysconfdir}/modules-load.d/mbp-t1-touchbar.conf

%changelog
* Mon Jul 13 2026 Vinicius Fontanela <[email protected]> - 1.0-2
- Fixed dkms.conf: removed custom MAKE[0] override that broke the
  module Makefile's kbuild-mode branch (make: No targets. Stop.)
- Removed deprecated REMAKE_INITRD directive
- Confirmed working on kernel 7.0.0-27

* Sun Jul 12 2026 Vinicius Fontanela <[email protected]> - 1.0-1
- Initial RPM packaging, mirroring the Debian package
