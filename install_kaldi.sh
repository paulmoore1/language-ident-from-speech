#!/bin/bash

PROG=`basename $0`;
usage="Usage: $PROG <arguments>\n
Installs KALDI in a specified directory.\n\n
Required arguments:\n
  --root-dir=DIR\tThe directory in which KALDI will be installed (in its own kaldi/ subdirectory)\n
";

if [ $# -lt 1 ]; then
  echo -e $usage; exit 1;
fi

INSTALLDIR=${1}/kaldi
mkdir -p $INSTALLDIR
echo "Installing KALDI in ${INSTALLDIR}"

echo \
$'\n#################################################
         Cloning KALDI source from GitHub           
#################################################\n'
git clone https://github.com/kaldi-asr/kaldi.git $INSTALLDIR

echo \
$'\n#################################################
         Building KALDI tools           
#################################################\n'
cd $INSTALLDIR/tools && make -j 4

echo \
$'\n#################################################
         Building KALDI binaries
#################################################\n'
cd ../src && ./configure --shared --use-cuda=yes && make -j 4
