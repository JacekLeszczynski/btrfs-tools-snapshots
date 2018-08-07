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
SCIEZKA_APT_KEY='$(which apt-key 2> /dev/null)'
DOLAR_APT_KEY='"$APT_KEY"'
DOLAR_WSTECZNY_SLASH='\'
DOLAR_PYTAJNIK='$?'
DOLAR_NEED_KEYS='$NEED_KEYS'
DOLAR_KEYDATA1='<<KEYDATA'
DOLAR_KEYDATA2='KEYDATA'

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

#Dodanie repozytorium do listy repozytoriów
if [ ! -e /etc/apt/sources.list.d/repozytorium_jacka_debian.list ]; then
  echo "deb https://packagecloud.io/repozytorium_jacka/debian/debian/ buster main" >/etc/apt/sources.list.d/repozytorium_jacka_debian.list
  echo "deb-src https://packagecloud.io/repozytorium_jacka/debian/debian/ buster main" >>/etc/apt/sources.list.d/repozytorium_jacka_debian.list
fi

#Dodanie grupy systemowej
groupadd -f --system $APPS
if [ -f /etc/sudoers.d/$APPS ]; then
  chown root:root /etc/sudoers.d/$APPS
  chmod 440 /etc/sudoers.d/$APPS
fi


$KOMENDA_POSTINST

echo 'APT::Upgrade::Pre-Invoke {"btrfs-tools-snapshots --auto --trigger dpkg";};' > /etc/apt/apt.conf.d/80btrfs-tools-snapshots
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


prepare_key_repo() {
cat - >cos <<KEYDATA
#!/bin/sh

#Dodanie klucza do apt-key
APT_KEY="${SCIEZKA_APT_KEY}"
if [ ! -x ${DOLAR_APT_KEY} ]; then
  return
fi
NEED_KEYS=0
${DOLAR_APT_KEY} export https://packagecloud.io/Jacek/debian 2>&1 | ${DOLAR_WSTECZNY_SLASH}
  grep -q -- "-----END PGP PUBLIC KEY BLOCK-----"
if [ $DOLAR_PYTAJNIK -ne 0 ]; then
  NEED_KEYS=1
fi
if [ $DOLAR_NEED_KEYS -eq 1 ]; then
  $DOLAR_APT_KEY add - >/dev/null 2>&1 $DOLAR_KEYDATA1
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.11 (GNU/Linux)

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
=M4pV
-----END PGP PUBLIC KEY BLOCK-----
$DOLAR_KEYDATA2
fi
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
