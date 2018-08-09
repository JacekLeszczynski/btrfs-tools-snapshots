#!/bin/bash

APPS="btrfs-tools-snapshots"
APPS2="btrfs-tools-snapshots-gui"
GENCONF="../conf/tool-gen-conf"

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
  if [ "$1" == "0" ]; then
    wewn_a="all"
  fi
  if [ "$1" == "32" ]; then
    wewn_a="i386"
  fi
  if [ "$1" == "64" ]; then
    wewn_a="amd64"
  fi
  $GENCONF --in ../conf/control --out debian/control --values "{ARCH}=$wewn_a"
}

prepare_changelog() {
  $GENCONF --in ../conf/changelog --out debian/changelog --values "{VER}=$VER ?DATE?"
}

prepare_preinst() {
  $GENCONF --in ../conf/preinst --out debian/preinst
}

prepare_postinst() {
  $GENCONF --in ../conf/postinst --out debian/postinst
}

prepare_prerm() {
  $GENCONF --in ../conf/prerm --out debian/prerm
}

prepare_postrm() {
  $GENCONF --in ../conf/postrm --out debian/postrm
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
#czysc_katalog
generuj_all_bit
czysc_katalog
cd ..

exit 0
