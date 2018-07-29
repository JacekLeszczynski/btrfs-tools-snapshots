#!/bin/bash

APPS="btrfs-tools-snapshots"
APPS2="btrfs-tools-snapshots-gui"

VER=`../$APPS.amd64 --ver`
DATE=`date`
echo "Generowana wersja pakietów to: $VER"

czysc_katalog() {
  echo "Czyszczę katalogi..."
  cd debian
  rm -f -r .debhelper
  rm -f -r $APPS
  rm -f -r etc
  rm -f -r usr
  rm -f $APPS.debhelper.log
  rm -f $APPS.substvars
  rm -f control
  rm -f changelog
  rm -f files
  rm -f postinst
  rm -f prerm
  rm -f ../usr/bin/$APPS
  rm -f ../usr/bin/$APPS2
  rm -f -r ../usr/share/$APPS
  cd ..
}

prepare_control() {
  echo "Source: $APPS" > debian/control
  echo "Section: tools" >> debian/control
  echo "Priority: extra" >> debian/control
  echo "Maintainer: Jacek Leszczyński <sam@bialan.pl>" >> debian/control
  echo "" >> debian/control
  echo "Package: $APPS" >> debian/control
  if [ "$1" == "0" ]; then
    echo "Architecture: all" >> debian/control
  fi
  if [ "$1" == "32" ]; then
    echo "Architecture: i386" >> debian/control
  fi
  if [ "$1" == "64" ]; then
    echo "Architecture: amd64" >> debian/control
  fi
  echo "Depends: ${shlibs:Depends}" >> debian/control
  echo "Description: System punktów przywracania BTRFS" >> debian/control
  echo " System punktów przywracania BTRFS" >> debian/control
}

prepare_changelog() {
  echo "$APPS ($VER) experimental; urgency=low" > debian/changelog
  echo "" >> debian/changelog
  echo "  * Prepared by alien version 8.95" >> debian/changelog
  echo "  " >> debian/changelog
  echo "" >> debian/changelog
  echo " -- Jacek Leszczyński <sam@bialan.pl>  $DATE" >> debian/changelog
}

prepare_postinst() {
  echo '#!/bin/sh' >debian/postinst
  echo '' >>debian/postinst
  echo 'set -e' >>debian/postinst
  echo '' >>debian/postinst
  echo 'if [ "$1" = configure ]; then' >>debian/postinst
  echo '' >>debian/postinst
  echo '  AR=$(arch)' >>debian/postinst
  echo '  if [ "$AR" = "x86_64" ]; then' >>debian/postinst
  echo "    ln -s /usr/share/$APPS/$APPS.amd64 /usr/bin/$APPS" >>debian/postinst
  echo "    ln -s /usr/share/$APPS/$APPS2.amd64 /usr/bin/$APPS2" >>debian/postinst
  echo '  else' >>debian/postinst
  echo "    ln -s /usr/share/$APPS/$APPS.i386 /usr/bin/$APPS" >>debian/postinst
  echo "    ln -s /usr/share/$APPS/$APPS2.i386 /usr/bin/$APPS2" >>debian/postinst
  echo '  fi' >>debian/postinst
  echo '' >>debian/postinst
  echo 'fi' >>debian/postinst
  echo '' >>debian/postinst
  echo 'if [ ! -e /etc/apt/sources.list.d/repozytorium_jacka_debian.list ]; then' >>debian/postinst
  echo '  echo "deb https://packagecloud.io/repozytorium_jacka/debian/debian/ buster main" >/etc/apt/sources.list.d/repozytorium_jacka_debian.list' >>debian/postinst
  echo '  echo "deb-src https://packagecloud.io/repozytorium_jacka/debian/debian/ buster main" >>/etc/apt/sources.list.d/repozytorium_jacka_debian.list' >>debian/postinst
  echo 'fi' >>debian/postinst
  echo '' >>debian/postinst
  echo "groupadd -f --system $APPS" >>debian/postinst
  echo "if [ -f /etc/sudoers.d/$APPS ]; then" >>debian/postinst
  echo "  chown root:root /etc/sudoers.d/$APPS" >>debian/postinst
  echo "  chmod 440 /etc/sudoers.d/$APPS" >>debian/postinst
  echo "fi" >>debian/postinst
  echo "" >>debian/postinst
  echo 'exit 0' >>debian/postinst
  echo '' >>debian/postinst
}

prepare_prerm() {
  echo '#!/bin/sh' > debian/prerm
  echo 'set -e' >> debian/prerm
  echo '# Automatically added by dh_installinit/11.2.1' >> debian/prerm
  echo "rm -f /usr/bin/$APPS" >> debian/prerm
  echo "rm -f /usr/bin/$APPS2" >> debian/prerm
  echo '# End automatically added section' >> debian/prerm
}

generuj_all_bit() {
  echo "Generuję pakiet DEB dla wszystkich architektur..."
  czysc_katalog
  prepare_control 0
  prepare_changelog
  prepare_postinst
  prepare_prerm
  mkdir ./usr/share/$APPS
  cp ../../$APPS.i386 ./usr/share/$APPS/
  cp ../../$APPS.amd64 ./usr/share/$APPS/
  cp ../../$APPS2.i386 ./usr/share/$APPS/
  cp ../../$APPS2.amd64 ./usr/share/$APPS/
  fakeroot ./debian/rules binary
}

generuj_32bit() {
  echo "Generuję pakiet DEB dla wersji 32 bitowej..."
  czysc_katalog
  prepare_control 32
  prepare_changelog
  cp ../../$APPS.i386 ./usr/bin/$APPS
  cp ../../$APPS2.i386 ./usr/bin/$APPS
  fakeroot ./debian/rules binary
}

generuj_64bit() {
  echo "Generuję pakiet DEB dla wersji 64 bitowej..."
  czysc_katalog
  prepare_control 64
  prepare_changelog
  cp ../../$APPS.amd64 ./usr/bin/$APPS
  cp ../../$APPS2.amd64 ./usr/bin/$APPS
  fakeroot ./debian/rules binary
}

cd $APPS
generuj_all_bit
czysc_katalog
cd ..

exit 0
