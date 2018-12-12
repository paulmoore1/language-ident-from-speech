#!/bin/bash -u

# Copyright 2012  Arnab Ghoshal

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

set -o errexit

function error_exit () {
  echo -e "$@" >&2; exit 1;
}

function read_dirname () {
  local dir_name=`expr "X$1" : '[^=]*=\(.*\)'`;
  [ -d "$dir_name" ] || mkdir -p "$dir_name" || error_exit "Directory '$dir_name' not found";
  local retval=`cd $dir_name 2>/dev/null && pwd || exit 1`
  echo $retval
}

PROG=`basename $0`;
usage="Usage: $PROG <arguments>\n
Prepare train, dev, eval file lists for a language.\n
e.g.: $PROG --config-dir=conf --corpus-dir=corpus --languages=\"GE PO SP\"\n\n
Required arguments:\n
  --config-dir=DIR\tDirecory containing the necessary config files\n
  --corpus-dir=DIR\tDirectory for the GlobalPhone corpus\n
  --languages=STR\tSpace separated list of two letter language codes\n
";

if [ $# -lt 4 ]; then
  error_exit $usage;
fi

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config-dir=*)
  CONFDIR=`read_dirname $1`; shift ;;
  --corpus-dir=*)
  GPDIR=`read_dirname $1`; shift ;;
  --languages=*)
  LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --data-dir=*)
  DATADIR=`read_dirname $1`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

# (1) check if the config files are in place:
pushd $CONFDIR > /dev/null
[ -f eval_spk.list ] || error_exit "$PROG: Eval-set speaker list not found.";
[ -f lang_codes.txt ] || error_exit "$PROG: Mapping for language name to 2-letter code not found.";

popd > /dev/null
[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

# Make data folders to contain all the language files.
for x in eval train; do
  mkdir -p $DATADIR/${x}
done

<<<<<<< HEAD

=======
>>>>>>> f8b93f2fade601ba578052172e1275faf117609e
# (2) get the various file lists (for audio, transcription, etc.) for the
# specified language.
printf "Preparing file lists ... "
for L in $LANGUAGES; do
  mkdir -p $DATADIR/$L/local/data
  local/gp_prep_flists.sh \
  	--corpus-dir=$GPDIR \
    --eval-spk=$CONFDIR/eval_spk.list \
    --lang-map=$CONFDIR/lang_codes.txt \
    --work-dir=$DATADIR $L >& $DATADIR/$L/prep_flists.log &
  # Running these in parallel since this does audio conversion (to figure out
  # which files cannot be processed) and takes some time to run.
done
wait;
echo "Done"
<<<<<<< HEAD

=======
>>>>>>> f8b93f2fade601ba578052172e1275faf117609e

# (3) Create directories to contain files needed in training and testing:
for L in $LANGUAGES; do
  printf "Language - ${L}: formatting train/test data ... "
  for x in train eval; do
    mkdir -p $DATADIR/$L/$x
    cp $DATADIR/$L/local/data/${x}_${L}_wav.scp $DATADIR/$L/$x/wav.scp
    cp $DATADIR/$L/local/data/${x}_${L}.spk2utt $DATADIR/$L/$x/spk2utt
    cp $DATADIR/$L/local/data/${x}_${L}.utt2spk $DATADIR/$L/$x/utt2spk
  done
  echo "Done"
done

# (4) Combine data from all languages into one big pile
train_dirs=()
eval_dirs=()
for L in $LANGUAGES; do
  train_dirs+=($DATADIR/$L/train)
  eval_dirs+=($DATADIR/$L/eval)
done
echo "Combining training directories: $(echo ${train_dirs[@]} | sed -e "s|${DATADIR}||g")"
echo "Combining evaluation directories: $(echo ${eval_dirs[@]} | sed -e "s|${DATADIR}||g")"
utils/combine_data.sh $DATADIR/train ${train_dirs[@]}
utils/combine_data.sh $DATADIR/eval ${eval_dirs[@]}


# (5) Add utt2lang and lang2utt files for the collected languaages
for x in train eval; do
  sed -e 's?[0-9]*$??' $DATADIR/${x}/utt2spk \
  > $DATADIR/${x}/utt2lang

  local/utt2lang_to_lang2utt.pl $DATADIR/${x}/utt2lang \
  > $DATADIR/${x}/lang2utt

done

echo "Finished data preparation."
