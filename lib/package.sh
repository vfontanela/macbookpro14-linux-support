# Turn a staged file tree into a noarch .rpm and a .deb with the same content.
# Sourced by the component build scripts. Set these, then call make_packages OUT:
#   NAME VERSION RELEASE SUMMARY DESCRIPTION LICENSE ROOT
#   RPM_REQUIRES DEB_DEPENDS     comma-separated; DEB_DEPENDS=none: no .deb
#   DEB_RECOMMENDS               optional, comma-separated
#   RPM_FILES                    %files lines (paths inside ROOT)
#   SETUP                        script inside the package, run as
#                                "SETUP install" after install/upgrade and
#                                "SETUP remove" before final removal
MAINTAINER="Vinicius Fontanela <vfontanela@gmail.com>"
URL=https://github.com/vfontanela/macbookpro14-linux-support

make_packages() {
  local out=$1 work
  work=$(mktemp -d)
  mkdir -p "$out"

  # RPM: the staged tree is copied as is into the buildroot.
  mkdir -p "$work/rpm"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  cat > "$work/rpm/SPECS/$NAME.spec" <<EOF
%global debug_package %{nil}
%global __os_install_post %{nil}
%define _build_id_links none
Name:      $NAME
Version:   $VERSION
Release:   $RELEASE%{?dist}
Summary:   $SUMMARY
License:   $LICENSE
URL:       $URL
BuildArch: noarch
Requires:  ${RPM_REQUIRES//,/ }

%description
$DESCRIPTION

%install
cp -a "$ROOT/." %{buildroot}/

%post
$SETUP install || :

%preun
if [ \$1 -eq 0 ]; then $SETUP remove || :; fi

%files
$RPM_FILES
EOF
  rpmbuild -bb --quiet --define "_topdir $work/rpm" --define "dist %{nil}" \
    "$work/rpm/SPECS/$NAME.spec"
  cp "$work"/rpm/RPMS/noarch/*.rpm "$out/"

  # DEB: same tree, same setup script.
  [[ $DEB_DEPENDS == none ]] && { rm -rf "$work"; return; }
  local deb=$work/deb
  cp -a "$ROOT" "$deb"
  mkdir -p "$deb/DEBIAN"
  {
    echo "Package: $NAME"
    echo "Version: $VERSION-$RELEASE"
    echo "Architecture: all"
    echo "Maintainer: $MAINTAINER"
    echo "Depends: $DEB_DEPENDS"
    [[ -z ${DEB_RECOMMENDS:-} ]] || echo "Recommends: $DEB_RECOMMENDS"
    echo "Section: kernel"
    echo "Priority: optional"
    echo "Homepage: $URL"
    echo "Description: $SUMMARY"
    sed 's/^$/./; s/^/ /' <<<"$DESCRIPTION"
  } > "$deb/DEBIAN/control"
  printf '#!/bin/sh\nset -e\n[ "$1" = configure ] && %s install || :\n' "$SETUP" > "$deb/DEBIAN/postinst"
  printf '#!/bin/sh\nset -e\n[ "$1" = remove ] && %s remove || :\n' "$SETUP" > "$deb/DEBIAN/prerm"
  chmod 755 "$deb/DEBIAN/postinst" "$deb/DEBIAN/prerm"
  dpkg-deb --root-owner-group -Zxz --build "$deb" "$out/${NAME}_$VERSION-${RELEASE}_all.deb" >/dev/null

  rm -rf "$work"
}
