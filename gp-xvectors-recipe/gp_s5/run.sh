#!/bin/bash -u

# Copyright 2012  Arnab Ghoshal

#
# Copyright 2016 by Idiap Research Institute, http://www.idiap.ch
#
# See the file COPYING for the licence associated with this software.
#
# Author(s):
#   Bogdan Vlasenko, February 2016
#


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

# This script shows the steps needed to build a recognizer for certain languages
# of the GlobalPhone corpus.
# !!! NOTE: The current recipe assumes that you have pre-built LMs.
echo "This shell script may run as-is on your system, but it is recommended
that you run the commands one by one by copying and pasting into the shell."
#exit 1;

if [[ "$CONDA_DEFAULT_ENV" == "" ]]; then
	echo "Seems like your conda environment is not activated. Use: source activate ENVNAME."
	exit
else
	echo "Conda environment '$CONDA_DEFAULT_ENV' active."
fi

[ -f helper_functions.sh ] && source ./helper_functions.sh \
  || echo "helper_functions.sh not found. Won't be able to set environment variables and similar."

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."

# CHECKING FOR AND INSTALLING REQUIRED TOOLS:
#  This recipe requires shorten (3.6.1) and sox (14.3.2).
#  If they are not found, the local/gp_install.sh script will install them.
local/gp_check_tools.sh $PWD path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

# Moved to path.sh
# Set the locations of the GlobalPhone corpus and language models
#GP_CORPUS=/afs/inf.ed.ac.uk/group/corpora/public/global_phone

# Don't need language models for LID.
# GP_LM=$PWD/language_models


# Set the languages that will actually be processed
export GP_LANGUAGES="CR TU"
# The following data preparation step actually converts the audio files from
# shorten to WAV to take out the empty files and those with compression errors.
local/gp_data_prep.sh \
	--config-dir=$PWD/conf \
	--corpus-dir=$GP_CORPUS \
	--languages="$GP_LANGUAGES" \
	--data-dir=/afs/inf.ed.ac.uk/user/s15/s1513472/gp-data \
	|| exit 1;
#local/gp_dict_prep.sh --config-dir $PWD/conf $GP_CORPUS $GP_LANGUAGES || exit 1;

exit

# Now make MFCC features.
for L in $GP_LANGUAGES; do
  mfccdir=mfcc/$L
  echo "computing MFCCs for language: $L"
  for x in train dev eval; do
    (
      steps/make_mfcc.sh --nj 6 --cmd "$train_cmd" data/$L/$x \
        exp/$L/make_mfcc/$x $mfccdir;
      echo " made MFCCs"
      steps/compute_cmvn_stats.sh data/$L/$x exp/$L/make_mfcc/$x $mfccdir;
      echo " computed CMVN stats"
    ) &
  done
done
wait;
exit

for L in $GP_LANGUAGES; do
  mkdir -p exp/$L/mono;
  steps/train_mono.sh --nj 10 --cmd "$train_cmd" \
    data/$L/train data/$L/lang exp/$L/mono >& exp/$L/mono/train.log &
done
wait;
