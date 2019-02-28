#!/bin/bash -u

# Copyright 2012  Arnab Ghoshal
# Copyright 2016 by Idiap Research Institute, http://www.idiap.ch
# Copyright 2018/2019 by Sam Sucik and Paul Moore
# See the file COPYING for the licence associated with this software.
# Author(s):
#   Bogdan Vlasenko, February 2016
#   Sam Sucik, Paul Moore, 2018/2019

[ -f helper_functions.sh ] && source ./helper_functions.sh \
  || echo "helper_functions.sh not found. Won't be able to set environment variables and similar."

[ -f conf/general_config.sh ] && source ./conf/general_config.sh \
  || echo "conf/general_config.sh not found or contains errors!"

[ -f conf/user_specific_config.sh ] && source ./conf/user_specific_config.sh \
  || echo "conf/user_specific_config.sh not found, create it by cloning " + \
          "conf/user_specific_config-example.sh"

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."

# CHECKING FOR AND INSTALLING REQUIRED TOOLS:
#  This recipe requires shorten (3.6.1) and sox (14.3.2).
#  If they are not found, the local/gp_install.sh script will install them.
./local/gp_check_tools.sh . path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }
DATADIR=/home/s1531206/gp-data/all_preprocessed
log_dir=$DATADIR/log
mfcc_dir=$DATADIR/mfcc
vaddir=$DATADIR/vad

# Set the languages that will actually be processed
GP_LANGUAGES="AR" # BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU WU VN"
#GP_LANGUAGES="AR"

echo "Running with languages: ${GP_LANGUAGES}"

for L in $GP_LANGUAGES; do
  echo "Prepping language ${L}"
  lang_dir=$DATADIR/${L}
  train=${L}_train
  train_data=$lang_dir/${train}
  train_slow=${train_data}_slow
  train_fast=${train_data}_fast
  train_speeds=${train_data}_speeds

  utils/perturb_data_dir_speed.sh 0.9 ${train_data} ${train_slow}
  utils/perturb_data_dir_speed.sh 1.1 ${train_data} ${train_fast}

  utils/data/get_utt2num_frames.sh ${train_slow}
  utils/data/get_utt2num_frames.sh ${train_fast}

  # Make features and compute the energy-based VAD for each dataset
  echo "#### Calculating MFCCs and VAD for perturbed data ####"
  for speed_dir in ${train_slow} ${train_fast}; do
    num_speakers=$(cat ${speed_dir}/spk2utt | wc -l)
    if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
      num_jobs=$MAXNUMJOBS
    else
      num_jobs=$num_speakers
    fi
    utils/fix_data_dir.sh ${speed_dir}
    # Get utt2lang files
    sed -e 's/\( sp0\.9-\)/ /' ${speed_dir}/utt2spk | sed -e 's?[0-9]*$??' > ${speed_dir}/utt2lang
    local/utt2lang_to_lang2utt.pl ${speed_dir}/utt2lang > ${speed_dir}/lang2utt

    echo "Creating 23D MFCC features."
    steps/make_mfcc.sh \
      --write-utt2num-frames false \
      --mfcc-config conf/mfcc.conf \
      --nj $num_jobs \
      --cmd "$train_cmd" \
      --compress true \
      ${speed_dir} \
      $log_dir/make_mfcc/${speed_dir} \
      $mfcc_dir/${L}

    echo "Fixing the directory to make sure everything is fine."
    utils/fix_data_dir.sh ${speed_dir}

    ./local/compute_vad_decision.sh \
      --nj $num_jobs \
      --cmd "$preprocess_cmd" \
      ${speed_dir} \
      $log_dir/make_vad/${speed_dir} \
      $vaddir/${L}

    utils/fix_data_dir.sh ${speed_dir}
  done

  # Combine the clean and augmented SWBD+SRE list.  This is now roughly
  # double the size of the original clean list.
  utils/combine_data.sh --extra-files 'utt2num_frames lang2utt' ${train_speeds} ${train_slow} ${train_data} ${train_fast}
  utils/fix_data_dir.sh ${train_speeds}

  echo "Done with data augmentation"
done
