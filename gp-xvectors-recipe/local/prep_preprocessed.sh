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
  --train-languages=STR\tSpace separated list of two letter language codes for training\n
  --enroll-languages=STR\tSpace separated list of two letter language codes for enrollment\n
  --eval-languages=STR\tSpace separated list of two letter language codes for evaluation\n
  --test-languages=STR\tSpace separated list of two letter language codes for testing\n
";

if [ $# -lt 12 ]; then
  error_exit $usage;
fi

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config-dir=*)
  CONFDIR=`read_dirname $1`; shift ;;
  --processed-dir=*)
  INDIR=`read_dirname $1`; shift ;;
  --data-augmentation=*)
  use_data_augmentation=$1; shift ;;
  --train-languages=*)
  TRAIN_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --enroll-languages=*)
  ENROLL_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --eval-languages=*)
  EVAL_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --test-languages=*)
  TEST_LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --config-file-path=*)
  config_file_path=`read_dirname $1`; shift ;;
  --enrollment-length=*)
  enrollment_length=$1; shift ;;
  --evaluation-length=*)
  evaluation_length=$1; shift ;;
  --test-length=*)
  test_length=$1; shift ;;
  --data-dir=*)
  OUTDIR=`read_dirname $1`; shift ;;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

# Make data folders to contain all the language files.
for x in train enroll eval test; do
  mkdir -p $OUTDIR/${x}
done

# Create directories to contain files needed in training and testing:
echo "Directory for storing is: $OUTDIR"
for L in $TRAIN_LANGUAGES; do
  train_dirs=()
  train_dirs+=($INDIR/$L/${L}_train)
  cp -r $INDIR/${L}/${L}_train
done

if [ "$use_data_augmentation" = true ]; then

else

fi

for L in $ENROLL_LANGUAGES; do

done

for L in $EVAL_LANGUAGES; do

done

for L in $TEST_LANGUAGES; do

done

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
