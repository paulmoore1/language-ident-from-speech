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
Prepare train, enroll, eval and test file lists for a language.\n
e.g.: $PROG --config-dir=conf --corpus-dir=corpus --languages=\"GE PO SP\"\n\n
Required arguments:\n
  --config-dir=DIR\tDirecory containing the necessary config files\n
  --corpus-dir=DIR\tDirectory for the GlobalPhone corpus\n
  --train-languages=STR\tSpace separated list of two letter language codes for training\n
  --enroll-languages=STR\tSpace separated list of two letter language codes for enrollment\n
  --eval-languages=STR\tSpace separated list of two letter language codes for evaluation\n
  --test-languages=STR\tSpace separated list of two letter language codes for testing\n
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
  --train-languages=*)
  TRAIN_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --enroll-languages=*)
  ENROLL_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --eval-languages=*)
  EVAL_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --test-languages=*)
  TEST_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --data-dir=*)
  datadir=`read_dirname $1`; shift ;;
  --wav-dir=*)
  WAVDIR=`read_dirname $1`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

# Check if the config files are in place:
pushd $CONFDIR > /dev/null
if [ -f test_spk.list ]; then
  test_list=$CONFDIR/test_spk.list
else
  echo "Test-set speaker list not found."; exit 1
fi
if [ -f eval_spk.list ]; then
  eval_list=$CONFDIR/eval_spk.list
else
  echo "Eval-set speaker list not found."; exit 1
fi
if [ -f enroll_spk.list ]; then
  enroll_list=$CONFDIR/enroll_spk.list
else
  echo "Enrollment-set speaker list not found."; exit 1
fi
if [ -f train_spk.list ]; then
  train_list=$CONFDIR/train_spk.list
fi
popd > /dev/null

[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

# Make data folders to contain all the language files.
for x in train enroll eval test; do
  mkdir -p $datadir/${x}
done

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
trap 'rm -rf "$tmpdir"' EXIT

# Create directories to contain files needed in training and testing:
echo "datadir is: $datadir"
for L in $TRAIN_LANGUAGES; do
  (
  mkdir -p $tmpdir/train/$L
  if [ -f $CONFDIR/train_spk.list ]; then
    grep "^$L" $train_list | cut -f2- | tr ' ' '\n' \
      | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/train/$L/train_spk
  else
    echo "Train-set speaker list not found. Skipping."
    #grep -v -f $tmpdir/$L/test_spk -f $tmpdir/$L/eval_spk -f $tmpdir/$L/enroll_spk \
    #  $WAVDIR/$L/lists/spk > $tmpdir/$L/train_spk || \
    #  echo "Could not find any training set speakers; \
    #  are you trying to use all of them for evaluation and testing?";
    continue
  fi

  echo "Language - ${L}: formatting train data."
  mkdir -p $datadir/$L/train
  rm -f $datadir/$L/train/wav.scp $datadir/$L/train/spk2utt \
        $datadir/$L/train/utt2spk $datadir/$L/train/utt2len

  for spk in `cat $tmpdir/train/$L/train_spk`; do
    grep -h "$spk" $WAVDIR/$L/lists/wav.scp >> $datadir/$L/train/wav.scp
    grep -h "$spk" $WAVDIR/$L/lists/spk2utt >> $datadir/$L/train/spk2utt
    grep -h "$spk" $WAVDIR/$L/lists/utt2spk >> $datadir/$L/train/utt2spk
    grep -h "$spk" $WAVDIR/$L/lists/utt2len >> $datadir/$L/train/utt2len
  done
  ) &
done
wait;
echo "Done"

for L in $ENROLL_LANGUAGES; do
  (
  mkdir -p $tmpdir/enroll/$L
  grep "^$L" $enroll_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/enroll/$L/enroll_spk
  echo "Language - ${L}: formatting enroll data."
  mkdir -p $datadir/$L/enroll
  rm -f $datadir/$L/enroll/wav.scp $datadir/$L/enroll/spk2utt \
        $datadir/$L/enroll/utt2spk $datadir/$L/enroll/utt2len

  for spk in `cat $tmpdir/enroll/$L/enroll_spk`; do
    grep -h "$spk" $WAVDIR/$L/lists/wav.scp >> $datadir/$L/enroll/wav.scp
    grep -h "$spk" $WAVDIR/$L/lists/spk2utt >> $datadir/$L/enroll/spk2utt
    grep -h "$spk" $WAVDIR/$L/lists/utt2spk >> $datadir/$L/enroll/utt2spk
    grep -h "$spk" $WAVDIR/$L/lists/utt2len >> $datadir/$L/enroll/utt2len
  done
  ) &
done
wait;
echo "Done"

for L in $EVAL_LANGUAGES; do
  (
  mkdir -p $tmpdir/eval/$L
  grep "^$L" $eval_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/eval/$L/eval_spk

  echo "Language - ${L}: formatting eval data."
  mkdir -p $datadir/$L/eval
  rm -f $datadir/$L/eval/wav.scp $datadir/$L/eval/spk2utt \
        $datadir/$L/eval/utt2spk $datadir/$L/eval/utt2len

  for spk in `cat $tmpdir/eval/$L/eval_spk`; do
    grep -h "$spk" $WAVDIR/$L/lists/wav.scp >> $datadir/$L/eval/wav.scp
    grep -h "$spk" $WAVDIR/$L/lists/spk2utt >> $datadir/$L/eval/spk2utt
    grep -h "$spk" $WAVDIR/$L/lists/utt2spk >> $datadir/$L/eval/utt2spk
    grep -h "$spk" $WAVDIR/$L/lists/utt2len >> $datadir/$L/eval/utt2len
  done
  ) &
done
wait;
echo "Done"
for L in $TEST_LANGUAGES; do
  (
  mkdir -p $tmpdir/test/$L
  grep "^$L" $test_list | cut -f2- | tr ' ' '\n' \
    | sed -e "s?^?$L?" -e 's?$?_?' > $tmpdir/test/$L/test_spk

  echo "Language - ${L}: formatting test data."
  mkdir -p $datadir/$L/test
  rm -f $datadir/$L/test/wav.scp $datadir/$L/test/spk2utt \
        $datadir/$L/test/utt2spk $datadir/$L/test/utt2len

  for spk in `cat $tmpdir/test/$L/test_spk`; do
    grep -h "$spk" $WAVDIR/$L/lists/wav.scp >> $datadir/$L/test/wav.scp
    grep -h "$spk" $WAVDIR/$L/lists/spk2utt >> $datadir/$L/test/spk2utt
    grep -h "$spk" $WAVDIR/$L/lists/utt2spk >> $datadir/$L/test/utt2spk
    grep -h "$spk" $WAVDIR/$L/lists/utt2len >> $datadir/$L/test/utt2len
  done
  ) &
done
wait;
echo "Done"

# Combine data from all languages into big piles
train_dirs=()
eval_dirs=()
enroll_dirs=()
test_dirs=()

for L in $TRAIN_LANGUAGES; do
  train_dirs+=($datadir/$L/train)
done
for L in $ENROLL_LANGUAGES; do
  enroll_dirs+=($datadir/$L/enroll)
done
for L in $EVAL_LANGUAGES; do
  eval_dirs+=($datadir/$L/eval)
done
for L in $TEST_LANGUAGES; do
  test_dirs+=($datadir/$L/test)
done


echo "Combining training directories: $(echo ${train_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/train ${train_dirs[@]}

echo "Combining enrollment directories: $(echo ${enroll_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/enroll ${enroll_dirs[@]}

echo "Combining evaluation directories: $(echo ${eval_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/eval ${eval_dirs[@]}

echo "Combining testing directories: $(echo ${test_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh --extra-files 'utt2len' $datadir/test ${test_dirs[@]}


# Add utt2lang and lang2utt files for the collected languages
for x in train enroll eval test; do
  sed -e 's?[0-9]*$??' $datadir/${x}/utt2spk \
  > $datadir/${x}/utt2lang

  ./local/utt2lang_to_lang2utt.pl $datadir/${x}/utt2lang \
  > $datadir/${x}/lang2utt
done

echo "Finished data preparation."
