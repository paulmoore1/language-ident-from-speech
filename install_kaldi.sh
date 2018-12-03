#!/bin/bash

PROG=`basename $0`;
usage="Usage: $PROG <arguments>\n
Installs KALDI in a specified directory.\n\n
Required arguments:\n
  --root-dir=DIR\tName of the directory Kaldi will be installed in (starting from the home directory, in its own subdirectory).
";

if [ $# -lt 1 ]; then
  echo -e $usage; exit 1;
fi

for i in "$@"
do
  case "$i" in
    --root-dir=*)
    dir_name="${i#*=}"
    shift ;;
    *) echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

INSTALLDIR=~/${dir_name}/kaldi
mkdir -p ${INSTALLDIR}
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
