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
root_data_dir=/home/s1531206/gp-data
DATADIR=$root_data_dir/all_preprocessed
rirs_dir=$root_data_dir/RIRS_NOISES
musan_dir=$root_data_dir/musan
log_dir=$DATADIR/log
mfcc_dir=$DATADIR/mfcc
vaddir=$DATADIR/vad

# Set the languages that will actually be processed
GP_LANGUAGES="KO PL PO RU SP SW TH TU WU VN"
#GP_LANGUAGES="AR"

echo "Running with languages: ${GP_LANGUAGES}"

# Preparing lists of utterances (and a couple other auxiliary lists) based
# on the train/enroll/eval/test splitting. The lists refer to the WAVs
# generated in the previous stage.
# NOTE: The wav-dir as it is right now only works in the cluster!
echo "#### STAGE 1: Organising speakers into sets. ####"

# Organise data into train, enroll, eval and test
./local/gp_data_organise_no_combine.sh \
  --config-dir=conf \
  --corpus-dir=$GP_CORPUS \
  --wav-dir=/mnt/mscteach_home/s1531206/lid/wav \
  --train-languages="$GP_LANGUAGES" \
  --enroll-languages="$GP_LANGUAGES" \
  --eval-languages="$GP_LANGUAGES" \
  --test-languages="$GP_LANGUAGES" \
  --data-dir=$DATADIR \
  || exit 1;

for L in $GP_LANGUAGES; do
  echo "Prepping language ${L}"
  lang_dir=$DATADIR/${L}
  train=${L}_train
  enroll=${L}_enroll
  eval=${L}_eval
  test=${L}_test
  train_data=$lang_dir/${train}
  enroll_data=$lang_dir/${enroll}
  eval_data=$lang_dir/${eval}
  test_data=$lang_dir/${test}


  for data_subset in ${train} ${enroll} ${eval} ${test}; do
    utils/data/get_utt2num_frames.sh $lang_dir/${data_subset}
  done

  echo "Splitting data"
  declare -a times=(3 10 30 60)
  for data_subset in ${enroll} ${eval} ${test}; do
    # Make a backup
    mkdir -p $lang_dir/${data_subset}/.unsplit_backup
    cp -r $lang_dir/${data_subset}/* $lang_dir/${data_subset}/.unsplit_backup
    for time in ${times[@]}; do
      echo "Splitting ${data_subset} data"
      local/split_long_utts.sh \
        --max-utt-len $time \
        $lang_dir/${data_subset} \
        $lang_dir/${data_subset}_split_${time}s
      utils/data/get_utt2num_frames.sh $lang_dir/${data_subset}_split_${time}s
    done
  done

  # Make features and compute the energy-based VAD for each dataset
  echo "#### Calculating MFCCs and VAD for unsplit data ####"
  for data_subset in ${train} ${enroll} ${eval} ${test}; do
    num_speakers=$(cat $lang_dir/${data_subset}/spk2utt | wc -l)
    if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
      num_jobs=$MAXNUMJOBS
    else
      num_jobs=$num_speakers
    fi
    utils/fix_data_dir.sh $lang_dir/${data_subset}

    echo "Creating 23D MFCC features."
    steps/make_mfcc.sh \
      --write-utt2num-frames false \
      --mfcc-config conf/mfcc.conf \
      --nj $num_jobs \
      --cmd "$train_cmd" \
      --compress true \
      $lang_dir/${data_subset} \
      $log_dir/make_mfcc/${data_subset} \
      $mfcc_dir

    echo "Fixing the directory to make sure everything is fine."
    utils/fix_data_dir.sh $lang_dir/${data_subset}

    ./local/compute_vad_decision.sh \
      --nj $num_jobs \
      --cmd "$preprocess_cmd" \
      $lang_dir/${data_subset} \
      $log_dir/make_vad/${data_subset} \
      $vaddir

    utils/fix_data_dir.sh $lang_dir/${data_subset}

  done
  echo "### Calcuating MFCCs and VAD for split data ####"
  for data_subset in ${enroll} ${eval} ${test}; do
    for time in ${times[@]}; do
      num_speakers=$(cat $lang_dir/${data_subset}_split_${time}s/spk2utt | wc -l)
      if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
        num_jobs=$MAXNUMJOBS
      else
        num_jobs=$num_speakers
      fi
      utils/fix_data_dir.sh $lang_dir/${data_subset}_split_${time}s

      echo "Creating 23D MFCC features."
      steps/make_mfcc.sh \
        --write-utt2num-frames false \
        --mfcc-config conf/mfcc.conf \
        --nj $num_jobs \
        --cmd "$train_cmd" \
        --compress true \
        $lang_dir/${data_subset}_split_${time}s \
        $log_dir/make_mfcc/${data_subset}_split_${time}s \
        $mfcc_dir

      echo "Fixing the directory to make sure everything is fine."
      utils/fix_data_dir.sh $lang_dir/${data_subset}_split_${time}s

      ./local/compute_vad_decision.sh \
        --nj $num_jobs \
        --cmd "$preprocess_cmd" \
        $lang_dir/${data_subset}_split_${time}s \
        $log_dir/make_vad/${data_subset}_split_${time}s \
        $vaddir

      utils/fix_data_dir.sh ${lang_dir}/${data_subset}_split_${time}s
    done
  done

  echo "Finished stage 2."


  # Data augmentation step
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' $train_data/utt2num_frames > $train_data/reco2dur

  # Make a version with reverberated speech
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, $rirs_dir/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, $rirs_dir/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the training data.  Note that we don't add any
  # additive noise here.
  # Make sure we have permission to execute (can be weird)
  chmod +x steps/data/augment_data_dir.py
  steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 16000 \
    ${root_data_dir} \
    ${train_data} ${train_data}_reverb
  # Durations are the same
  cp ${train_data}/utt2dur ${train_data}_reverb
  cp ${train_data}/vad.scp ${train_data}_reverb
  utils/copy_data_dir.sh --utt-suffix "-reverb" ${train_data}_reverb ${train_data}_reverb.new
  rm -rf ${train_data}_reverb
  mv ${train_data}_reverb.new ${train_data}_reverb


  # Augment with musan_noise
  steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "${musan_dir}/musan_noise" ${train_data} ${train_data}_noise
  # Augment with musan_music
  steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "${musan_dir}/musan_music" ${train_data} ${train_data}_music
  # Augment with musan_speech
  steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "${musan_dir}/musan_speech" ${train_data} ${train_data}_babble

  # Combine reverb, noise, music, and babble into one directory.
  utils/combine_data.sh ${train_data}_aug ${train_data}_reverb ${train_data}_noise ${train_data}_music ${train_data}_babble

  # Make MFCCs for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  echo "Making MFCCs for augmented data"
  steps/make_mfcc.sh \
  --mfcc-config conf/mfcc.conf \
  --nj $num_jobs \
  --cmd "$train_cmd" \
  ${train_data}_aug \
  $log_dir/make_mfcc/${L}_train_aug \
  $mfcc_dir

  echo "Tidying up data"

  # Combine the clean and augmented SWBD+SRE list.  This is now roughly
  # double the size of the original clean list.
  utils/combine_data.sh ${train_data}_combined ${train_data}_aug ${train_data}
  utils/fix_data_dir.sh ${train_data}_combined

  # Remove unnecessary folders
  rm -rf ${train_data}_music
  rm -rf ${train_data}_noise
  rm -rf ${train_data}_reverb
  rm -rf ${train_data}_babble
  # Have the aug subset and clean data which is enough (both are separate)

  # Get back necessary files for training
  utils/data/get_utt2num_frames.sh ${train_data}_combined
  sed -e 's?[0-9]*$??' ${train_data}_combined/utt2spk > ${train_data}_combined/utt2lang
  local/utt2lang_to_lang2utt.pl ${train_data}_combined/utt2lang > ${train_data}_combined/lang2utt

  echo "Done with data augmentation"
done
