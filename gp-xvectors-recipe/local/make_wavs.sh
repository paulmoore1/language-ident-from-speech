#!/bin/bash -u

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
usage="Usage: $PROG <arguments>\n
Convert all SHN files of given languages into WAV, saving list of generated WAVs, spk2utt and utt2spk.\n\n
Required arguments:\n
  --corpus-dir=DIR\tDirectory for the GlobalPhone corpus\n
  --wav-dir=DIR\t\tPlace to write the WAV files and lists\n
  --lang-map=FILE\tMapping from 2-letter language code to full name\n
  --languages=STR\tString of space-separated language codes, e.g. 'FR RU'\n
";

# LANGUAGES=""
# GPDIR="/disk/scratch/lid/global_phone"
# WAVDIR="disk/scratch/lid/wav"

while [ $# -gt 0 ];
do
  case "$1" in
  # --help) echo -e $usage; exit 0 ;;
  --corpus-dir=*)
  GPDIR=`read_dirname $1`; shift ;;
  --wav-dir=*)
  WAVDIR=`read_dirname $1`; shift ;;
  --languages=*)
  LANGUAGES=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --lang-map=*)
  LANGMAP=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

echo "Languages: ${LANGUAGES}"
echo "Corpus dir: ${GPDIR}"
echo "Wav dir: ${WAVDIR}"

[ -f path.sh ] && . ./path.sh  # Sets the PATH to contain necessary executables

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
trap 'rm -rf "$tmpdir"' EXIT

for L in $LANGUAGES; do
  (
  LNAME=`awk '/'$L'/ {print $2}' $LANGMAP`;
  echo "Converting $L ($LNAME) data from SHN to WAV..."

  LISTDIR=$WAVDIR/$L/lists # Directory to write file lists
  FILEDIR=$WAVDIR/$L/files # Directory to write wav files
  mkdir -p $LISTDIR $FILEDIR

  find $GPDIR/$LNAME/adc -name "${L}*_1\.adc\.shn" > $LISTDIR/shn.list
  
  gp_convert_audio.sh \
    --input-list=$LISTDIR/shn.list \
    --output-dir=$FILEDIR \
    --output-list=$LISTDIR/wav.list

  # Get the utterance IDs for the audio files successfully converted to WAV
  sed -e "s?.*/??" -e 's?.wav$??' $LISTDIR/wav.list > $LISTDIR/basenames_wav

  paste $LISTDIR/basenames_wav $LISTDIR/wav.list | sort -k1,1 \
    > $LISTDIR/wav.scp

  sed -e 's?_.*$??' $LISTDIR/basenames_wav \
    | paste -d' ' $LISTDIR/basenames_wav - \
    > $LISTDIR/utt2spk

  utt2spk_to_spk2utt.pl $LISTDIR/utt2spk \
    > $LISTDIR/spk2utt || exit 1;

  grep -ohE "[A-Z]+[0-9]+ " $LISTDIR/spk2utt \
    | grep -ohE "[0-9]+" | sort | uniq -u > $LISTDIR/spk

  rm $LISTDIR/basenames_wav
  ) > $WAVDIR/${L}_log &
done
wait;
exit
