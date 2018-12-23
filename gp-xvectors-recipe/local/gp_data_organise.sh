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
Prepare train, eval_test, eval_enroll file lists for a language.\n
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
  --wav-dir=*)
  WAVDIR=`read_dirname $1`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

# Use the default lists unless a 'proper' one is found (same name, without the "example")
eval_test_list=$CONFDIR/eval_test_example.list
eval_enroll_list=$CONFDIR/eval_enroll_example.list

# (1) check if the config files are in place:
pushd $CONFDIR > /dev/null
if [ -f eval_enroll_spk.list ]; then
  eval_enroll_list=$CONFDIR/eval_enroll_spk.list
else
  echo "Enrollment-set speaker list not found. Using default list"
fi
if [ -f eval_test_spk.list ]; then
  eval_test_list=$CONFDIR/eval_test_spk.list
else
  echo "Test-set speaker list not found. Using default list"
fi
if [ -f train_spk.list ]; then
  train_list=$CONFDIR/train_spk.list
fi

[ -f lang_codes.txt ] || error_exit "$PROG: Mapping for language name to 2-letter code not found.";

popd > /dev/null
[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

# Make data folders to contain all the language files.
for x in train eval_test eval_enroll; do
  mkdir -p $DATADIR/${x}
done

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
trap 'rm -rf "$tmpdir"' EXIT


# (2) get the various file lists (for audio, transcription, etc.) for the
# specified language.
# printf "Preparing file lists ... "
# for L in $LANGUAGES; do
#   mkdir -p $DATADIR/$L/local/data
#   ./local/gp_prep_flists.sh \
#     --corpus-dir=$GPDIR \
#     --train-spk=$CONFDIR/train_spk.list \
#     --eval-test-spk=$eval_test_list \
#     --eval-enroll-spk=$eval_enroll_list \
#     --lang-map=$CONFDIR/lang_codes.txt \
#     --work-dir=$DATADIR \
#     $L >& $DATADIR/$L/prep_flists.log &
#   # Running these in parallel since this does audio conversion (to figure out
#   # which files cannot be processed) and takes some time to run.
# done
# wait;
# echo "Done"

# (3) Create directories to contain files needed in training and testing:
for L in $LANGUAGES; do
  grep "^$L" $eval_enroll_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/eval_enroll_spk
  grep "^$L" $eval_test_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/eval_test_spk
  if [ -f $CONFDIR/train_spk.list ]; then
    grep "^$L" $train_list | cut -f2- | tr ' ' '\n' \
      | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/train_spk
  else
    echo "Train-set speaker list not found. Using all speakers not in eval set."
    grep -v -f $tmpdir/eval_test_spk -f $tmpdir/eval_enroll_spk $WAVDIR/$L/lists/spk \
      > $tmpdir/train_spk || echo "Could not find any training set speakers; \
      are you trying to use all of them for evaluation and testing?";
  fi
  
  printf "Language - ${L}: formatting train/test data ... "
  for x in train eval_test eval_enroll; do
    mkdir -p $DATADIR/$L/$x
    rm -f $DATADIR/$L/$x/wav.scp $DATADIR/$L/$x/spk2utt $DATADIR/$L/$x/utt2spk

    for spk in `cat "${x}_spk"`; do
      echo $spk
      grep -o "$spk" $WAVDIR/$L/lists/wav.scp >> $DATADIR/$L/$x/wav.scp
      grep -o "$spk" $WAVDIR/$L/lists/spk2utt >> $DATADIR/$L/$x/spk2utt
      grep -o "$spk" $WAVDIR/$L/lists/utt2spk >> $DATADIR/$L/$x/utt2spk
      # cp $DATADIR/$L/local/data/${x}_${L}_wav.scp $DATADIR/$L/$x/wav.scp
      # cp $DATADIR/$L/local/data/${x}_${L}.spk2utt $DATADIR/$L/$x/spk2utt
      # cp $DATADIR/$L/local/data/${x}_${L}.utt2spk $DATADIR/$L/$x/utt2spk
    done
  done
  echo "Done"
done

exit

# (4) Combine data from all languages into big piles
train_dirs=()
eval_test_dirs=()
eval_enroll_dirs=()
for L in $LANGUAGES; do
  train_dirs+=($DATADIR/$L/train)
  eval_test_dirs+=($DATADIR/$L/eval_test)
  eval_enroll_dirs+=($DATADIR/$L/eval_enroll)
done
echo "Combining training directories: $(echo ${train_dirs[@]} | sed -e "s|${DATADIR}||g")"
echo "Combining evaluation test directories: $(echo ${eval_test_dirs[@]} | sed -e "s|${DATADIR}||g")"
echo "Combining evaluation enrollment directories: $(echo ${eval_enroll_dirs[@]} | sed -e "s|${DATADIR}||g")"
utils/combine_data.sh $DATADIR/train ${train_dirs[@]}
utils/combine_data.sh $DATADIR/eval_test ${eval_test_dirs[@]}
utils/combine_data.sh $DATADIR/eval_enroll ${eval_enroll_dirs[@]}


# (5) Add utt2lang and lang2utt files for the collected languages
# Don't bother with test data
for x in train eval_enroll eval_test; do
  sed -e 's?[0-9]*$??' $DATADIR/${x}/utt2spk \
  > $DATADIR/${x}/utt2lang

  local/utt2lang_to_lang2utt.pl $DATADIR/${x}/utt2lang \
  > $DATADIR/${x}/lang2utt

done

echo "Finished data preparation."
