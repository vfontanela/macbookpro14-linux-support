#!/usr/bin/env python3
"""Build clean, independent FaceTime HD RPM/DEB DKMS source packages (no firmware)."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
NAME = 'macbook-facetimehd-dkms'
VERSION = '0.7.2.git20260929'
MODULE = f'facetimehd-{VERSION}'


def run(*args, **kwargs):
    subprocess.run(args, check=True, **kwargs)


def stage(dest, family):
    source = dest/'usr/src'/MODULE
    source.mkdir(parents=True)
    # Explicit source manifest excludes generated objects even in a dirty checkout.
    files = ['Makefile', 'dkms.conf', 'LICENSE', 'README.md']
    files += [p.name for p in sorted((ROOT/'src').glob('fthd_*.c'))]
    files += [p.name for p in sorted((ROOT/'src').glob('fthd_*.h'))]
    for file in files:
        shutil.copyfile(ROOT/'src'/file, source/file)
        (source/file).chmod(0o644)
    if f'PACKAGE_VERSION="{VERSION}"' not in (source/'dkms.conf').read_text():
        raise ValueError('DKMS/package version mismatch')
    libexec = dest/'usr/libexec/macbook-facetimehd'
    libexec.mkdir(parents=True)
    for script in ['hardware.sh', 'install-dkms.sh']:
        shutil.copyfile(ROOT/'scripts'/script, libexec/script)
        (libexec/script).chmod(0o755)
    firmware = libexec/'facetimehd-firmware-install.sh'
    shutil.copyfile(ROOT/'firmware-tool'/firmware.name, firmware)
    firmware.chmod(0o755)
    binary = dest/'usr/bin/macbook-facetimehd'
    binary.parent.mkdir(parents=True)
    firmware_root = '/usr/lib/firmware' if family == 'rpm' else '/lib/firmware'
    binary.write_text((ROOT/'scripts/macbook-facetimehd').read_text().replace('@FIRMWARE_ROOT@', firmware_root))
    binary.chmod(0o755)
    docs = dest/f'usr/share/doc/{NAME}'
    docs.mkdir(parents=True)
    for file in ['README.md', 'UPSTREAM.md', 'docs/HARDWARE-TEST.md', 'CHANGELOG.md']:
        shutil.copyfile(ROOT/file, docs/Path(file).name)
    shutil.copyfile(ROOT/'src/LICENSE', docs/'COPYING.driver')
    shutil.copyfile(ROOT/'firmware-tool/LICENSE', docs/'COPYING.firmware-tool')
    for file in docs.iterdir():
        file.chmod(0o644)
    # All parent directories and metadata must be accessible regardless of umask.
    for directory in dest.rglob('*'):
        if directory.is_dir():
            directory.chmod(0o755)


def preinstall():
    return 'set -e\n' + (ROOT/'scripts/hardware.sh').read_text() + '\nfacetimehd_require_hardware\n'


def build(output):
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='macbook-camera-build-') as temp:
        temp = Path(temp)
        deb = temp/'deb'
        stage(deb, 'deb')
        control = deb/'DEBIAN'
        control.mkdir()
        (control/'control').write_text(f'''Package: {NAME}
Version: {VERSION}-1
Architecture: all
Section: kernel
Priority: optional
Maintainer: Vinicius Fontanela <vfontanela@users.noreply.github.com>
Depends: dkms (>= 3.0), bash, kmod, pciutils, v4l-utils, make, gcc, libc6-dev, curl, ca-certificates, xz-utils, gzip, cpio, coreutils
Recommends: linux-headers-amd64 | linux-headers-generic
Conflicts: facetimehd-dkms, bcwc-pcie-dkms
Description: Modular FaceTime HD PCIe camera support for compatible Intel Macs
 Hardware-gated facetimehd DKMS sources and local Apple firmware extraction.
 No proprietary firmware is included. Requires PCI ID 14e4:1570.
''')
        (control/'preinst').write_text('#!/bin/bash\ncase "$1" in install|upgrade)\n'+preinstall()+';;\nesac\n')
        (control/'postinst').write_text('#!/bin/bash\nset -e\nif [[ "$1" == configure ]]; then\n    /usr/libexec/macbook-facetimehd/install-dkms.sh\nfi\n')
        (control/'prerm').write_text(f'''#!/bin/bash
set -e
if [[ "$1" == remove || "$1" == deconfigure ]]; then
    if dkms status -m facetimehd -v {VERSION} | grep -q .; then
        dkms remove -m facetimehd -v {VERSION} --all
    fi
fi
''')
        (control/'postrm').write_text('#!/bin/bash\nif [[ "$1" == remove || "$1" == purge ]]; then depmod -a || true; fi\n')
        for script in ['preinst', 'postinst', 'prerm', 'postrm']:
            (control/script).chmod(0o755)
            run('bash', '-n', str(control/script))
        (control/'control').chmod(0o644)
        run('dpkg-deb', '--root-owner-group', '--build', str(deb), str(output/f'{NAME}_{VERSION}-1_all.deb'))

        top = temp/'rpm'
        for folder in ['BUILD', 'BUILDROOT', 'SOURCES', 'SPECS', 'SRPMS', 'RPMS']:
            (top/folder).mkdir(parents=True)
        # Source RPM contains the complete packaging, provenance and GPL sources.
        src = temp/f'{NAME}-{VERSION}'
        src.mkdir()
        for file in ['build.py', 'README.md', 'UPSTREAM.md', 'CHANGELOG.md']:
            shutil.copyfile(ROOT/file, src/file)
        for directory in ['src', 'firmware-tool', 'scripts', 'docs', 'tests']:
            shutil.copytree(ROOT/directory, src/directory, ignore=shutil.ignore_patterns('__pycache__', '*.ko', '*.o', '*.cmd', '*.mod', '*.mod.c', 'Module.symvers', 'modules.order'))
        stage(src/'payload', 'rpm')
        run('tar', '--owner=0', '--group=0', '--numeric-owner', '-czf', str(top/'SOURCES'/f'{NAME}-{VERSION}.tar.gz'), '-C', str(temp), src.name)
        spec = top/'SPECS'/f'{NAME}.spec'
        spec.write_text(f'''Name: {NAME}
Version: {VERSION}
Release: 1%{{?dist}}
Summary: Modular FaceTime HD PCIe camera DKMS support for compatible Intel Macs
License: GPL-2.0-only
URL: https://github.com/vfontanela/macbookpro14-linux-support
Source0: %{{name}}-%{{version}}.tar.gz
BuildArch: noarch
Requires: dkms >= 3.0, bash, kmod, pciutils, v4l-utils, make, gcc, kernel-devel
Requires: curl, ca-certificates, xz, gzip, cpio, coreutils, grep
Requires(pre): bash, coreutils
Requires(post): dkms, bash
Requires(preun): dkms, bash
Conflicts: facetimehd-dkms, bcwc-pcie-dkms
%description
Separate FaceTime HD PCIe camera component for PCI ID 14e4:1570.
Ships GPL driver sources and a local firmware extraction tool, no firmware blobs.
%prep
%setup -q
%build
%install
mkdir -p %{{buildroot}}
cp -a payload/. %{{buildroot}}/
%pre -p /bin/bash
{preinstall()}
%post -p /bin/bash
/usr/libexec/macbook-facetimehd/install-dkms.sh
%preun -p /bin/bash
if [[ "$1" -eq 0 ]]; then
    if dkms status -m facetimehd -v {VERSION} | grep -q .; then
        dkms remove -m facetimehd -v {VERSION} --all || true
    fi
fi
%postun
depmod -a || true
%files
/usr/src/{MODULE}
/usr/bin/macbook-facetimehd
/usr/libexec/macbook-facetimehd
%doc /usr/share/doc/{NAME}/README.md
%doc /usr/share/doc/{NAME}/UPSTREAM.md
%doc /usr/share/doc/{NAME}/HARDWARE-TEST.md
%doc /usr/share/doc/{NAME}/CHANGELOG.md
%license /usr/share/doc/{NAME}/COPYING.driver
%license /usr/share/doc/{NAME}/COPYING.firmware-tool
%changelog
* Thu Oct 01 2026 Vinicius Fontanela - {VERSION}-1
- Add hardware-gated modular DKMS camera support; no proprietary firmware.
''')
        shutil.copyfile(spec, output/f'{NAME}.spec')
        run('rpmbuild', '--define', f'_topdir {top}', '-ba', str(spec))
        for folder in ['RPMS', 'SRPMS']:
            for rpm in (top/folder).rglob('*.rpm'):
                shutil.copyfile(rpm, output/rpm.name)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    build(parser.parse_args().output.resolve())
