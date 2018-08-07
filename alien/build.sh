#!/bin/bash

APPS="btrfs-tools-snapshots"
APPS2="btrfs-tools-snapshots-gui"

PROG="$APPS.amd64"
VER=`../$PROG --ver`
DATE=`date`
echo "Generowana wersja pakietów to: $VER"

DOLAR='$'
DOLAR_JEDEN='$1'
DOLAR_ARCH='$(arch)'
KOMENDA_POSTINST="$APPS --postinst"


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
  rm -f preinst
  rm -f postinst
  rm -f prerm
  rm -f postrm
  rm -f ../etc/default/$APPS
  rm -f ../usr/bin/$APPS
  rm -f ../usr/bin/$APPS2
  rm -f -r ../usr/share/$APPS
  cd ..
}


prepare_control() {
depends='${shlibs:Depends}'
if [ "$1" == "0" ]; then
  wewn_a="Architecture: all"
fi
if [ "$1" == "32" ]; then
  wewn_a="Architecture: i386"
fi
if [ "$1" == "64" ]; then
  wewn_a="Architecture: amd64"
fi
cat - >debian/control <<KEYDATA
Source: $APPS
Section: tools
Priority: extra
Maintainer: Jacek Leszczyński <sam@bialan.pl>

Package: $APPS
$wewn_a
Depends: ${depends}
Description: System punktów przywracania BTRFS
 System punktów przywracania BTRFS
KEYDATA
}


prepare_changelog() {
cat - >debian/changelog <<KEYDATA
$APPS ($VER) experimental; urgency=low

  * Prepared by alien version 8.95


 -- Jacek Leszczyński <sam@bialan.pl>  $DATE
KEYDATA
}

prepare_preinst() {
cat - >debian/preinst <<KEYDATA
#!/bin/sh' >debian/preinst

set -e

exit 0
KEYDATA
}


prepare_postinst() {
echo "--------------------------- $DOLAR_ARCH"
DOLAR_AR='$'.'AR'
cat - >debian/postinst <<KEYDATA
#!/bin/sh

set -e

if [ "$DOLAR_JEDEN" = configure ]; then

  AR=$DOLAR_ARCH
  if [ "${DOLAR}AR" = "x86_64" ]; then
    ln -s /usr/share/$APPS/$APPS.amd64 /usr/bin/$APPS
    ln -s /usr/share/$APPS/$APPS2.amd64 /usr/bin/$APPS2
  else
    ln -s /usr/share/$APPS/$APPS.i386 /usr/bin/$APPS
    ln -s /usr/share/$APPS/$APPS2.i386 /usr/bin/$APPS2
  fi

fi

if [ ! -e /etc/apt/sources.list.d/repozytorium_jacka_debian.list ]; then
  echo "deb https://packagecloud.io/repozytorium_jacka/debian/debian/ buster main" >/etc/apt/sources.list.d/repozytorium_jacka_debian.list
  echo "deb-src https://packagecloud.io/repozytorium_jacka/debian/debian/ buster main" >>/etc/apt/sources.list.d/repozytorium_jacka_debian.list
fi

groupadd -f --system $APPS
if [ -f /etc/sudoers.d/$APPS ]; then
  chown root:root /etc/sudoers.d/$APPS
  chmod 440 /etc/sudoers.d/$APPS
fi

$KOMENDA_POSTINST

echo 'DPkg::Pre-Invoke {"btrfs-tools-snapshots --auto --trigger dpkg";};' > /etc/apt/apt.conf.d/80btrfs-tools-snapshots
echo '#!/bin/sh' > /etc/cron.daily/btrfs-tools-snapshots
echo '' >> /etc/cron.daily/btrfs-tools-snapshots
echo 'btrfs-tools-snapshots --auto --trigger cron.daily' >> /etc/cron.daily/btrfs-tools-snapshots
echo '#!/bin/sh' > /etc/cron.weekly/btrfs-tools-snapshots
echo '' >> /etc/cron.weekly/btrfs-tools-snapshots
echo 'btrfs-tools-snapshots --auto --trigger cron.weekly' >> /etc/cron.weekly/btrfs-tools-snapshots
chmod +x /etc/cron.daily/btrfs-tools-snapshots
chmod +x /etc/cron.weekly/btrfs-tools-snapshots

exit 0

KEYDATA
}


prepare_prerm() {
cat - >debian/prerm <<KEYDATA
#!/bin/sh

set -e

# Automatically added by dh_installinit/11.2.1
if [ -e /etc/cron.daily/btrfs-tools-snapshots ]; then
  rm -f /etc/cron.daily/btrfs-tools-snapshots
fi
if [ -e /etc/cron.weekly/btrfs-tools-snapshots ]; then
  rm -f /etc/cron.weekly/btrfs-tools-snapshots
fi
if [ -e /etc/apt/apt.conf.d/80btrfs-tools-snapshots ]; then
  rm -f /etc/apt/apt.conf.d/80btrfs-tools-snapshots
fi
# End automatically added section
KEYDATA
}


prepare_postrm() {
cat - >debian/postrm <<KEYDATA
#!/bin/sh

set -e

# Automatically added by dh_installinit/11.2.1
rm -f /usr/bin/$APPS
rm -f /usr/bin/$APPS2
# End automatically added section
KEYDATA
}


generuj_all_bit() {
  echo "Generuję pakiet DEB dla wszystkich architektur..."
  czysc_katalog
  prepare_control 0
  prepare_changelog
  prepare_postinst
  prepare_prerm
  prepare_postrm
  mkdir ./usr/share/$APPS
  `../../$PROG --save-conf ./etc/default/btrfs-tools-snapshots`
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
  prepare_postinst
  prepare_prerm
  prepare_postrm
  `../../$PROG --save-conf ./etc/default/btrfs-tools-snapshots`
  cp ../../$APPS.i386 ./usr/bin/$APPS
  cp ../../$APPS2.i386 ./usr/bin/$APPS
  fakeroot ./debian/rules binary
}


generuj_64bit() {
  echo "Generuję pakiet DEB dla wersji 64 bitowej..."
  czysc_katalog
  prepare_control 64
  prepare_changelog
  prepare_postinst
  prepare_prerm
  prepare_postrm
  `../../$PROG --save-conf ./etc/default/btrfs-tools-snapshots`
  cp ../../$APPS.amd64 ./usr/bin/$APPS
  cp ../../$APPS2.amd64 ./usr/bin/$APPS
  fakeroot ./debian/rules binary
}


cd $APPS
czysc_katalog
generuj_all_bit
czysc_katalog
cd ..

exit 0
