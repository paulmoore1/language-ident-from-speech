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
set -o pipefail

function read_dirname () {
  local dir_name=`expr "X$1" : '[^=]*=\(.*\)'`;
  [ -d "$dir_name" ] || mkdir -p "$dir_name" || { echo "Directory '$dir_name' not found." >&2; \
    exit 1; }
  local retval=`cd $dir_name 2>/dev/null && pwd || exit 1`
  echo $retval
}

PROG=`basename $0`;
usage="Usage: $PROG <arguments> <2-letter language code>\n
Prepare train, dev, eval file lists for a language.\n\n
Required arguments:\n
  --corpus-dir=DIR\tDirectory for the GlobalPhone corpus\n
  --eval-spk=FILE\tEval set speaker list\n
  --unlabelled-spk=FILE\tUnlabelled set speaker list\n
  --lang-map=FILE\tMapping from 2-letter language code to full name\n
  --work-dir=DIR\t\tPlace to write the files (in a subdirectory with the 2-letter language code)\n
";

if [ $# -lt 4 ]; then
  echo -e $usage; exit 1;
fi

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --corpus-dir=*)
  GPDIR=`read_dirname $1`; shift ;;
  --work-dir=*)
  WDIR=`read_dirname $1`; shift ;;
  --eval-spk=*)
  EVALSPK=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --unlabelled-spk=*)
  UNLABELLEDSPK=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --lang-map=*)
  LANGMAP=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  ??) LCODE=$1; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
#LCODE is for instance, FR

[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
trap 'rm -rf "$tmpdir"' EXIT

grep "^$LCODE" $UNLABELLEDSPK | cut -f2- | tr ' ' '\n' \
  | sed -e "s?^?$LCODE?" -e 's?$?_?' > $tmpdir/unlabelled_spk
grep "^$LCODE" $EVALSPK | cut -f2- | tr ' ' '\n' \
  | sed -e "s?^?$LCODE?" -e 's?$?_?' > $tmpdir/eval_spk

# Currently the Dev/Eval info is missing for some languages and is marked
# by either TBA or XXX in the speaker list. We are currently not processing
# such languages.
egrep 'XXX|TBA' $tmpdir/unlabelled_spk \
  && { echo "Unlabelled speaker list not defined. File contents:"; \
    cat $tmpdir/unlabelled_spk; exit 1; }
egrep 'XXX|TBA' $tmpdir/eval_spk \
  && { echo "Eval speaker list not defined. File contents:"; \
    cat $tmpdir/eval_spk; exit 1; }

# We are going to use the 2-letter codes throughout, but the top-level
# directories of the GlobalPhone corpus use the full names of languages.
full_name=`awk '/'$LCODE'/ {print $2}' $LANGMAP`;
ls "$GPDIR/$full_name/adc" | sed -e "s?^?$LCODE?" -e 's?$?_?' \
  > $tmpdir/all_spk

grep -v -f $tmpdir/eval_spk -f $tmpdir/unlabelled_spk $tmpdir/all_spk \
  > $tmpdir/train_spk || echo "Could not find any training set speakers; \
  are you trying to use all of them for evaluation and testing?";

echo "All speakers"
cat $tmpdir/all_spk
echo "Eval speakers"
cat $tmpdir/eval_spk
echo "Train speakers"
cat $tmpdir/train_spk
echo "Unlabelled speakers"
cat $tmpdir/unlabelled_spk


ODIR=$WDIR/$LCODE/local/data     # Directory to write file lists
mkdir -p $ODIR $WDIR/$LCODE/wav  # Directory for WAV files

echo "Preparing file lists, putting into $ODIR"
for x in eval train unlabelled; do
  echo "Converting $x data from SHN to WAV..."
  # Can add 087 to the file name so that only one speaker is counted
  # Added 1 to the end to reduce number
  find $GPDIR/$full_name/adc -name "${LCODE}*\.adc\.shn" \
     | grep -f $tmpdir/${x}_spk > $ODIR/${x}_${LCODE}.flist
  # The audio conversion is done here since some files cannot be converted,
  # and those need to be removed from the file lists.
  # Unfortunately this needs to be done here, since sox doesn't play nice when
  # called directly from compute-mfcc-feats as a piped command.
  gp_convert_audio.sh --input-list=$ODIR/${x}_${LCODE}.flist \
    --output-dir=$WDIR/$LCODE/wav \
    --output-list=$ODIR/${x}_${LCODE}_wav.flist &

  # Get the utterance IDs for the audio files successfully converted to WAV
  sed -e "s?.*/??" -e 's?.wav$??' $ODIR/${x}_${LCODE}_wav.flist \
    > $tmpdir/${x}_basenames_wav
  paste $tmpdir/${x}_basenames_wav $ODIR/${x}_${LCODE}_wav.flist | sort -k1,1 \
    > $ODIR/${x}_${LCODE}_wav.scp

  sed -e 's?_.*$??' $tmpdir/${x}_basenames_wav \
    | paste -d' ' $tmpdir/${x}_basenames_wav - \
    > $ODIR/${x}_${LCODE}.utt2spk

  utt2spk_to_spk2utt.pl $ODIR/${x}_${LCODE}.utt2spk \
    > $ODIR/${x}_${LCODE}.spk2utt || exit 1;
done
wait;

# Either do this or the original (above, lines 99-124). Basically equivalent, so inefficient to do both
:<<TRANSCRIPT
for x in eval train; do
  find $GPDIR/$full_name/adc -name "${LCODE}*\.adc\.shn" \
    | grep -f $tmpdir/${x}_spk > $ODIR/${x}_${LCODE}.flist

  #echo "SHN files for ${x} set:"
  #cat $ODIR/${x}_${LCODE}.flist | sed "s/.*\///g" | sed "s/^/\t/g"

  # The audio conversion is done here since some files cannot be converted,
  # and those need to be removed from the file lists.
  # Unfortunately this needs to be done here, since sox doesn't play nice when
  # called directly from compute-mfcc-feats as a piped command.
  gp_convert_audio.sh --input-list=$ODIR/${x}_${LCODE}.flist \
    --output-dir=$WDIR/$LCODE/wav \
    --output-list=$ODIR/${x}_${LCODE}_wav.flist

  # Get the utterance IDs for the audio files successfully converted to WAV
  sed -e "s?.*/??" -e 's?.wav$??' $ODIR/${x}_${LCODE}_wav.flist \
    > $tmpdir/${x}_basenames_wav
  paste $tmpdir/${x}_basenames_wav $ODIR/${x}_${LCODE}_wav.flist | sort -k1,1 \
    > $tmpdir/${x}_${LCODE}_wav.scp
  cut -f1 $tmpdir/${x}_${LCODE}_wav.scp > $tmpdir/${x}_basenames_wav2

  # Now, get the transcripts: each line of the output contains an utterance
  # ID followed by the transcript.
  sed -e 's?_$??' $tmpdir/${x}_spk | grep -f - $trans \
    | gp_extract_transcripts.pl | sort -k1,1 > $tmpdir/${x}_${LCODE}.trans

  # Intersect the set of utterances with transcripts with the set of those
  # with valid audio.
  cut -f1 $tmpdir/${x}_${LCODE}.trans \
    | join $tmpdir/${x}_basenames_wav2 - > $tmpdir/${x}_basenames
  # Get the common set of WAV files and transcripts.
  join $tmpdir/${x}_basenames $tmpdir/${x}_${LCODE}_wav.scp \
    > $ODIR/${x}_${LCODE}_wav.scp
  join $tmpdir/${x}_basenames $tmpdir/${x}_${LCODE}.trans \
    > $ODIR/${x}_${LCODE}.trans1

  sed -e 's?_.*$??' $tmpdir/${x}_basenames \
    | paste -d' ' $tmpdir/${x}_basenames - \
    > $ODIR/${x}_${LCODE}.utt2spk
  echo "$(sort -u $ODIR/${x}_${LCODE}.utt2spk)" > $ODIR/${x}_${LCODE}.utt2spk

  utt2spk_to_spk2utt.pl $ODIR/${x}_${LCODE}.utt2spk \
    > $ODIR/${x}_${LCODE}.spk2utt || exit 1;
done
TRANSCRIPT
