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
  --train-config-file-path=*)
  train_file_path=`read_dirname $1`; shift ;;
  --enroll-config-file-path=*)
  enroll_file_path=`read_dirname $1`; shift ;;
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
train_dirs_clean=()
train_dirs_aug=()
for L in $TRAIN_LANGUAGES; do
  if [ "$use_data_augmentation" = true ]; then
    train_dirs_aug+=($INDIR/$L/${L}_train_aug)
    train_dirs_clean+=($INDIR/$L/${L}_train)
  else
    train_dirs_clean+=($INDIR/$L/${L}_train)
  fi
done

if [ "$use_data_augmentation" = true ]; then
  echo "Combining training directories: $(echo ${train_dirs_clean[@]} | sed -e "s|${OUTDIR}||g")"
  utils/combine_data.sh --extra-files 'utt2len' $OUTDIR/train ${train_dirs_clean[@]}
  echo "Combining training directories: $(echo ${train_dirs_aug[@]} | sed -e "s|${OUTDIR}||g")"
  utils/combine_data.sh --extra-files 'utt2len' $OUTDIR/train_aug ${train_dirs_aug[@]}
else
  echo "Combining training directories: $(echo ${train_dirs_clean[@]} | sed -e "s|${OUTDIR}||g")"
  utils/combine_data.sh --extra-files 'utt2len' $OUTDIR/train ${train_dirs_clean[@]}
fi

train_data=$OUTDIR/train

echo "Shortening languages for training data"
python local/shorten_languages.py \
  --data-dir $train_data \
  --conf-file-path ${train_file_path} \
  >> ${train_data}/data_organisation

# For filtering the frames based on the new shortened utterances:
utils/filter_scp.pl ${train_data}/utterances_shortened ${train_data}/wav.scp > $DATADIR/${data_subset}/wav.scp.temp
mv ${train_data}/wav.scp.temp ${train_data}/wav.scp
# Fixes utt2spk, spk2utt, utt2lang, utt2num_frames files
utils/fix_data_dir.sh ${train_data}
# Fixes the lang2utt file
./local/utt2lang_to_lang2utt.pl ${train_data}/utt2lang \
> ${train_data}/lang2utt


enroll_dirs=()
for L in $ENROLL_LANGUAGES; do
  enroll_dir_lang=$INDIR/$L/${L}_enroll_split_${enrollment_length}s
  if [ -d $enroll_dir_lang ]; then
    enroll_dirs+=($enroll_dir_lang)
  else
    echo "Directory not found: $enroll_dir_lang"
    exit 1
done

enroll_data=$OUTDIR/enroll

echo "Combining enrollment directories: $(echo ${enroll_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh ${enroll_data} ${enroll_dirs[@]}

echo "Shortening languages for enrollment data"
python ./local/shorten_languages.py \
  --data-dir $enroll_data \
  --conf-file-path ${enroll_file_path} \
  >> ${enroll_data}/data_organisation

# For filtering the frames based on the new shortened utterances:
utils/filter_scp.pl ${enroll_data}/utterances_shortened ${enroll_data}/wav.scp > ${enroll_data}/wav.scp.temp
mv ${enroll_data}/wav.scp.temp ${enroll_data}/wav.scp
# Fixes utt2spk, spk2utt, utt2lang, utt2num_frames files
utils/fix_data_dir.sh ${enroll_data}
# Fixes the lang2utt file
./local/utt2lang_to_lang2utt.pl ${enroll_data}/utt2lang \
> ${enroll_data}/lang2utt


eval_dirs=()
for L in $EVAL_LANGUAGES; do
  eval_dir_lang=$INDIR/$L/${L}_eval_split_${evaluation_length}s
  if [ -d $eval_dir_lang ]; then
    eval_dirs+=($eval_dir_lang)
  else
    echo "Directory not found: $eval_dir_lang"
    exit 1
done

echo "Combining evaluation directories: $(echo ${eval_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh $OUTDIR/eval ${eval_dirs[@]}

test_dirs=()
for L in $TEST_LANGUAGES; do
  test_dir_lang=$INDIR/$L/${L}_test_split_${test_length}s
  if [ -d $test_dir_lang ]; then
    test_dirs+=($test_dir_lang)
  else
    echo "Directory not found: $test_dir_lang"
    exit 1
done

echo "Combining testing directories: $(echo ${test_dirs[@]} | sed -e "s|${datadir}||g")"
utils/combine_data.sh $OUTDIR/test ${test_dirs[@]}

echo "Finished data preparation."
