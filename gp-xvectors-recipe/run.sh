#!/bin/bash -u

# Copyright 2012  Arnab Ghoshal
#
# Copyright 2016 by Idiap Research Institute, http://www.idiap.ch
#
# Copyright 2018/2019 by Sam Sucik and Paul Moore
#
# See the file COPYING for the licence associated with this software.
#
# Author(s):
#   Bogdan Vlasenko, February 2016
#   Sam Sucik and Paul Moore, 2018/2019
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


usage="+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
\t       This shell script runs the GlobalPhone+X-vectors recipe.\n
\t       Use like this: $0 <options>\n
\t       --home-dir=DIRECTORY\tMain directory where recipe is stored
\t       --exp-config=FILE\tConfig file with all kinds of options,\n
\t       \t\t\tsee conf/exp_default.conf for an example.\n
\t       \t\t\tNOTE: Where arguments are passed on the command line,\n
\t       \t\t\tthe values overwrite those found in the config file.\n\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Default option values
exp_name="baseline"
stage=-1
run_all=false
exp_config=NONE
num_epochs=3
feature_type=mfcc
skip_nnet_training=false
use_model_from=NONE
use_data_augmentation=false
use_preprocessed=false
aug_expt=

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --home-dir=*)
  home_dir=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --exp-config=*)
  exp_config=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
echo -e $usage

# Run from the home directory
cd $home_dir
conf_dir=$home_dir/conf
exp_conf_dir=$conf_dir/exp_configs

if [ ! "$exp_config" == "NONE" ] && [ ! -f $exp_conf_dir/$exp_config ]; then
  echo "Configuration file '${exp_config}' not found for this experiment."
  exit 1;
fi

# Source some variables from the experiment-specific config file
source $exp_conf_dir/$exp_config || echo "Problems sourcing the experiment config file: $exp_conf_dir/$exp_config"

echo "Running experiment: '$exp_name'"

if [ $stage -eq -1 ]; then
  if [ "$run_all" = true ]; then
    echo "No stage specified and --run-all=true, running all stages."
    stage=0
  else
    echo "No stage specified and --run-all=false, not running any stages."
    exit 1;
  fi
else
  if [ "$run_all" = true ]; then
    echo "Running all stages starting with $stage."
  else
    echo "Running only stage $stage."
  fi
fi

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
./local/gp_check_tools.sh $home_dir path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

root_data_dir=$DATADIR
rirs_dir=$root_data_dir/RIRS_NOISES
musan_dir=$root_data_dir/musan

if [ -d $DATADIR/$exp_name ]; then
  echo "Experiment with name '$exp_name' already exists."
fi

if [ ! -d $rirs_dir ]; then
  echo "RIRS data not found. Downloading and unzipping"
  wget --no-check-certificate -P $root_data_dir http://www.openslr.org/resources/28/rirs_noises.zip
  unzip $root_data_dir/rirs_noises.zip
  rm $root_data_dir/rirs_noises.zip
fi


if [ ! -d $musan_dir ]; then
  echo "MUSAN data not set up. Setting up now"
  # Assumes MUSAN data is already present at the file path shown at /home..
  local/make_musan.sh /home/s1531206/musan $musan_dir
  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh $musan_dir/musan_${name}
    mv $musan_dir/musan_${name}/utt2dur $musan_dir/musan_${name}/reco2dur
  done
fi

home_prefix=$DATADIR/$exp_name
train_data=$home_prefix/train
enroll_data=$home_prefix/enroll
eval_data=$home_prefix/eval
test_data=$home_prefix/test
tamil_data=$home_prefix/tamil
log_dir=$home_prefix/log
mfcc_dir=$home_prefix/mfcc
vaddir=$home_prefix/vad
feat_dir=$home_prefix/x_vector_features
nnet_train_data=$home_prefix/nnet_train_data
nnet_dir=$home_prefix/nnet
exp_dir=$home_prefix/exp

# If using existing preprocessed data for computing x-vectors
if [ ! -z "$use_dnn_egs_from" ]; then
  home_prefix=$DATADIR/$use_dnn_egs_from
  echo "Using preprocessed data	from: $home_prefix"

  if [ ! -d $home_prefix ]; then
    echo "ERROR: directory containging preprocessed data not found: '$home_prefix'"
    exit 1
  fi

  train_data=$home_prefix/train
  enroll_data=$home_prefix/enroll
  eval_data=$home_prefix/eval
  test_data=$home_prefix/test
  nnet_train_data=$home_prefix/nnet_train_data
  preprocessed_data_dir=$DATADIR/$use_dnn_egs_from
fi

# Check any requested model exists
if [ -d $DATADIR/$use_model_from/nnet ]; then
  skip_nnet_training=true
  nnet_dir=$DATADIR/$use_model_from/nnet
  echo "Model found!"
else
  echo "Model not found in $DATADIR/$use_model_from/nnet"
fi

echo "Running with training languages: ${GP_TRAIN_LANGUAGES}"
echo "Running with enrollment languages: ${GP_ENROLL_LANGUAGES}"
echo "Running with evaluation languages: ${GP_EVAL_LANGUAGES}"
echo "Running with test languages: ${GP_TEST_LANGUAGES}"

# The most time-consuming stage: Converting SHNs to WAVs. Should be done only once;
# then, this script can be run from stage 0 onwards.
if [ $stage -eq 42 ]; then
  echo "#### SPECIAL STAGE 42: Converting all SHN files to WAV files. ####"
  ./local/make_wavs.sh \
    --corpus-dir=$GP_CORPUS \
    --wav-dir=$HOME/lid/wav \
    --lang-map=$conf_dir/lang_codes.txt \
    --languages="$GP_LANGUAGES"

  echo "Finished stage 42."
fi

# If there is a clean experiment directory to use (implying a previous augmentation experiment)
if [ ! -z "$aug_expt" ]; then
  echo "Using clean data from augmented experiment $aug_expt"
  echo "directory = $DATADIR/$aug_expt"
  if [ -d $DATADIR/$aug_expt ]; then
    prefix=$DATADIR/$aug_expt
    train_data=$prefix/train_clean
    enroll_data=$prefix/enroll
    eval_data=$prefix/eval
    test_data=$prefix/test
  else
    echo "Error: augmented experiment directory not found"
    exit 1
  fi
  # Skip to stage 3 since data already exists
  if [ "$run_all" = true ]; then
    stage=3
  else
    exit
  fi
fi

DATADIR="${DATADIR}/$exp_name"
mkdir -p $DATADIR
mkdir -p $DATADIR/log
echo "The experiment directory is: $DATADIR"

if [ "$use_preprocessed" = true ]; then
  processed_dir=~/gp-data/all_preprocessed
  ./local/prep_preprocessed.sh \
    --config-dir=$conf_dir \
    --processed-dir=$processed_dir \
    --data-augmentation=$use_data_augmentation \
    --train-languages="$GP_TRAIN_LANGUAGES" \
    --enroll-languages="$GP_ENROLL_LANGUAGES" \
    --eval-languages="$GP_EVAL_LANGUAGES" \
    --test-languages="$GP_TEST_LANGUAGES" \
    --data-dir=$DATADIR \
    --train-config-file-path=${conf_dir}/lre_configs/${lre_train_config} \
    --enroll-config-file-path=${conf_dir}/lre_configs/${lre_enroll_config} \
    --enrollment-length=$enrollment_length \
    --evaluation-length=$evaluation_length \
    --test-length=$test_length \
    > $processed_dir/output
  echo "Finished running"
  if [ "$run_all" = true ]; then
    stage=3
  else
    exit
  fi
fi

# Preparing lists of utterances (and a couple other auxiliary lists) based
# on the train/enroll/eval/test splitting. The lists refer to the WAVs
# generated in the previous stage.
# Runtime: Under 5 mins
if [ $stage -eq 1 ]; then
  # NOTE: The wav-dir as it is right now only works in the cluster!
  echo "#### STAGE 1: Organising speakers into sets. ####"
  (
  # Organise data into train, enroll, eval and test
  ./local/gp_data_organise.sh \
    --config-dir=$conf_dir \
    --corpus-dir=$GP_CORPUS \
    --wav-dir=/mnt/mscteach_home/s1531206/lid/wav \
    --train-languages="$GP_TRAIN_LANGUAGES" \
    --enroll-languages="$GP_ENROLL_LANGUAGES" \
    --eval-languages="$GP_EVAL_LANGUAGES" \
    --test-languages="$GP_TEST_LANGUAGES" \
    --data-dir=$DATADIR \
    || exit 1;

  ) > $log_dir/data_organisation

  if [ "$skip_nnet_training" == true ]; then
    # Get utt2num frames information for using when restricting the amount of data
    for data_subset in enroll eval test; do
      utils/data/get_utt2num_frames.sh $DATADIR/${data_subset}
    done
    echo "Shortening languages for enrollment data"
    python ./local/shorten_languages.py \
      --data-dir $enroll_data \
      --conf-file-path ${conf_dir}/lre_configs/${lre_enroll_config} \
      >> $log_dir/data_organisation

    # For filtering the frames based on the new shortened utterances:
    utils/filter_scp.pl $enroll_data/utterances_shortened $enroll_data/wav.scp > $enroll_data/wav.scp.temp
    mv $enroll_data/wav.scp.temp $enroll_data/wav.scp
    # Fixes utt2spk, spk2utt, utt2lang, utt2num_frames files
    utils/fix_data_dir.sh $enroll_data
    # Fixes the lang2utt file
    ./local/utt2lang_to_lang2utt.pl $enroll_data/utt2lang \
    > $enroll_data/lang2utt

    # Fix again, just to make sure
    utils/fix_data_dir.sh $enroll_data
  else
    # Get utt2num frames information for using when restricting the amount of data
    for data_subset in train enroll eval test; do
      utils/data/get_utt2num_frames.sh $DATADIR/${data_subset}
    done

    echo "Shortening languages for training data"
    python ./local/shorten_languages.py \
      --data-dir $train_data \
      --conf-file-path ${conf_dir}/lre_configs/${lre_train_config} \
      >> $log_dir/data_organisation
    echo "Shortening languages for enrollment data"
    python ./local/shorten_languages.py \
      --data-dir $enroll_data \
      --conf-file-path ${conf_dir}/lre_configs/${lre_enroll_config} \
      >> $log_dir/data_organisation

    for data_subset in train enroll; do
      # For filtering the frames based on the new shortened utterances:
      utils/filter_scp.pl $DATADIR/${data_subset}/utterances_shortened $DATADIR/${data_subset}/wav.scp > $DATADIR/${data_subset}/wav.scp.temp
      mv $DATADIR/${data_subset}/wav.scp.temp $DATADIR/${data_subset}/wav.scp
      # Fixes utt2spk, spk2utt, utt2lang, utt2num_frames files
      utils/fix_data_dir.sh $DATADIR/${data_subset}
      # Fixes the lang2utt file
      ./local/utt2lang_to_lang2utt.pl $DATADIR/${data_subset}/utt2lang \
      > $DATADIR/${data_subset}/lang2utt

      # Fix again, just to make sure
      utils/fix_data_dir.sh $DATADIR/${data_subset}
    done
  fi

  # Keep a backup of unsplit data
  for data_subset in enroll eval test; do
    mkdir -p $DATADIR/$data_subset/.unsplit_backup
    cp -r $DATADIR/$data_subset/* $DATADIR/$data_subset/.unsplit_backup
  done

  # NOTE Splitting after shortening enrollment data ensures that it will all be there.
  # Currently split_long_utts.sh doesn't affect wav.scp so need to do it in this order
  # Split enroll data into segments of < 30s.
  # TO-DO: Split into segments of various lengths (LID X-vector paper has 3-60s)
  echo "Splitting enrollment data"
  ./local/split_long_utts.sh \
    --max-utt-len $enrollment_length \
    $enroll_data \
    ${enroll_data}/split

  # Put in separate directory then transfer the split data over since doing it in
  # the same directory produces weird results
  # Split eval and testing utterances into segments of the same length (3s, 10s, 30s)
  # TO-DO: Allow for some variation, or do strictly this length?
  echo "Splitting evaluation data"
  ./local/split_long_utts.sh \
    --max-utt-len $evaluation_length \
    $eval_data \
    ${eval_data}/split

  echo "Splitting test data"
  ./local/split_long_utts.sh \
    --max-utt-len $test_length \
    $test_data \
    ${test_data}/split

  #NB this replaces the data previously stored. The unsplit lists are in .backup
   echo "Fixing datasets after splitting"
   for data_subset in enroll eval test; do
     utils/fix_data_dir.sh $DATADIR/${data_subset}/split
     utils/data/get_utt2num_frames.sh $DATADIR/${data_subset}/split
     mv $DATADIR/${data_subset}/split/* $DATADIR/${data_subset}/
     utils/fix_data_dir.sh $DATADIR/${data_subset}
   done

  echo "Finished stage 1."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Make features and compute the energy-based VAD for each dataset
# Runtime: ~12 mins
if [ $stage -eq 2 ]; then
  echo "#### STAGE 2: features (MFCC, SDC, etc) and VAD. ####"

  # Don't bother getting features for training data
  if [ "$skip_nnet_training" == true ]; then
    declare -a data_subsets=(enroll eval test)
  else
    declare -a data_subsets=(train enroll eval test)
  fi

  for data_subset in ${data_subsets[@]}; do
    (
    num_speakers=$(cat $DATADIR/${data_subset}/spk2utt | wc -l)
    if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
      num_jobs=$MAXNUMJOBS
    else
      num_jobs=$num_speakers
    fi

    echo "Creating 23D MFCC features."
    steps/make_mfcc.sh \
      --write-utt2num-frames false \
      --mfcc-config conf/mfcc.conf \
      --nj $num_jobs \
      --cmd "$preprocess_cmd" \
      --compress true \
      $DATADIR/${data_subset} \
      $log_dir/make_mfcc \
      $mfcc_dir

    echo "Fixing the directory to make sure everything is fine."
    utils/fix_data_dir.sh $DATADIR/${data_subset}

    ./local/compute_vad_decision.sh \
      --nj $num_jobs \
      --cmd "$preprocess_cmd" \
      $DATADIR/${data_subset} \
      $log_dir/make_vad \
      $vaddir

    utils/fix_data_dir.sh $DATADIR/${data_subset}
    ) > $log_dir/${feature_type}_${data_subset}
  done

  # Data augmentation step
  # Do data augmentation if required
  if [ "$use_data_augmentation" = true ]; then
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
    #utils/data/get_utt2dur.sh ${train_data}_reverb
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

    # Get target number of utterances for the subset of the augmented data
    # Set so it's about 2.5x the normal data (4x augmented / 1.6 = 2.5)
    num_utts=$(wc -l ${train_data}_aug/utt2spk | cut -d' ' -f1)
    target_utts=$(echo ${num_utts}/1.6 | bc)
    # Take a random subset of the augmentations
    utils/subset_data_dir.sh ${train_data}_aug $target_utts ${train_data}_aug_subset
    utils/fix_data_dir.sh ${train_data}_aug_subset

    # Make MFCCs for the augmented data.  Note that we do not compute a new
    # vad.scp file here.  Instead, we use the vad.scp from the clean version of
    # the list.

    num_speakers=$(cat ${train_data}_aug_subset/spk2utt | wc -l)
    if [ "$num_speakers" -gt "$MAXNUMJOBS" ]; then
      num_jobs=$MAXNUMJOBS
    else
      num_jobs=$num_speakers
    fi

    echo "Making MFCCs for augmented data"
    steps/make_mfcc.sh \
    --mfcc-config conf/mfcc.conf \
    --nj $num_jobs \
    --cmd "$train_cmd" \
      ${train_data}_aug_subset \
      $log_dir/make_mfcc \
      $mfcc_dir

    echo "Tidying up data"
    # Keep original clean copy of training data as backup
    cp -r $train_data ${train_data}_clean

    # Combine the clean and augmented SWBD+SRE list.  This is now roughly
    # double the size of the original clean list.
    utils/combine_data.sh ${train_data}_combined ${train_data}_aug_subset ${train_data}_clean
    rm -rf ${train_data}
    mv ${train_data}_combined ${train_data}
    utils/fix_data_dir.sh ${train_data}

    # Remove unnecessary folders
    rm -rf ${train_data}_music
    rm -rf ${train_data}_noise
    rm -rf ${train_data}_reverb
    rm -rf ${train_data}_babble
    rm -rf ${train_data}_aug
    # Have the aug subset and clean data which is enough (both are separate)

    # Get back necessary files for training
    utils/data/get_utt2num_frames.sh ${train_data}
    sed -e 's?[0-9]*$??' ${train_data}/utt2spk > ${train_data}/utt2lang
    local/utt2lang_to_lang2utt.pl ${train_data}/utt2lang > ${train_data}/lang2utt
    cp ${train_data}_clean/utterances_shortened_summary ${train_data}

    echo "Done with data augmentation"
  else
    echo "No data augmentation required"
  fi

  echo "Finished stage 2."

  if [ "$run_all" = true ]; then
    if [ "$skip_nnet_training" = true ]; then
      echo "Skipping NN training"
      stage=`expr $stage + 5`
    else
      stage=`expr $stage + 1`
    fi
  else
    echo "Run all is false; exiting..."
    exit
  fi
fi

# Now we prepare the features to generate examples for xvector training.
# Runtime: ~2 mins
if [ $stage -eq 3 ]; then
  # NOTE silence not being removed
  echo "#### STAGE 3: Preprocessing for X-vector training examples. ####"
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  ./local/prepare_feats_for_egs.sh \
    --nj $MAXNUMJOBS \
    --cmd "$preprocess_cmd" \
    $train_data \
    $nnet_train_data \
    $feat_dir

	utils/data/get_utt2num_frames.sh $nnet_train_data
  utils/fix_data_dir.sh $nnet_train_data

  echo "Finished stage 3."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# NOTE main things we need to work on are the num-repeats and num-jobs parameters
# Runtime: ~8.5 hours
# TO-DO: Find out the runtime without using GPUs.
if [ $stage -eq 4 ]; then
  echo "#### STAGE 4: Training the X-vector DNN. ####"
  if [ ! -z "$use_dnn_egs_from" ]; then
    ./local/run_xvector.sh \
      --stage 5 \
      --train-stage -1 \
      --num-epochs $num_epochs \
      --max-num-jobs $MAXNUMJOBS \
      --data $nnet_train_data \
      --nnet-dir $nnet_dir \
      --egs-dir $preprocessed_data_dir/nnet/egs
  else
    ./local/run_xvector.sh \
      --stage 4 \
      --train-stage -1 \
      --num-epochs $num_epochs \
      --max-num-jobs $MAXNUMJOBS \
      --data $nnet_train_data \
      --nnet-dir $nnet_dir \
      --egs-dir $nnet_dir/egs
  fi

  echo "Finished stage 4."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 3`
  else
    exit
  fi
fi

# Runtime: ~1:05h
if [ $stage -eq 7 ]; then
  echo "#### STAGE 7: Extracting X-vectors from the trained DNN. ####"

  if [[ $(whichMachine) == cluster* ]]; then
    use_gpu=true
  else
    use_gpu=false
  fi
  remove_nonspeech=false
  # X-vectors for training the classifier
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    --stage 0 \
    --remove-nonspeech "$remove_nonspeech" \
    $nnet_dir \
    $enroll_data \
    $exp_dir/xvectors_enroll &

  # X-vectors for end-to-end evaluation
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    --stage 0 \
    --remove-nonspeech "$remove_nonspeech" \
    $nnet_dir \
    $eval_data \
    $exp_dir/xvectors_eval &

  # X-vectors for testing (final evaluation)
  #./local/extract_xvectors.sh \
  #  --cmd "$extract_cmd --mem 6G" \
  #  --use-gpu $use_gpu \
  #  --nj $MAXNUMJOBS \
  #  --stage 0 \
  #  $nnet_dir \
  #  $test_data \
  #  $exp_dir/xvectors_test &

  wait;

  echo "Finished stage 7."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    echo "Stage completed without continuing"
    exit
  fi
fi

# Using logistic regression as a classifier (adapted from egs/lre07/v2,
# described in https://arxiv.org/pdf/1804.05000.pdf)
# Runtime: ~ 3min
if [ $stage -eq 8 ]; then
  echo "#### STAGE 8: Training logistic regression classifier and classifying test utterances. ####"
  # Make language-int map (essentially just indexing the languages 0 to L)
  langs=($GP_ENROLL_LANGUAGES)
  i=0
  for l in "${langs[@]}"; do
    echo $l $i
    i=$(expr $i + 1)
  done > conf/test_languages.list

  mkdir -p $exp_dir/results
  mkdir -p $exp_dir/classifier

  # Training the log reg model and classifying test set samples
  ./local/run_logistic_regression.sh \
    --prior-scale 0.70 \
    --conf conf/logistic-regression.conf \
    --train-dir $exp_dir/xvectors_enroll \
    --test-dir $exp_dir/xvectors_eval \
    --model-dir $exp_dir/classifier \
    --classification-file $exp_dir/results/classification \
    --train-utt2lang $enroll_data/utt2lang \
    --test-utt2lang $eval_data/utt2lang \
    --languages conf/test_languages.list \
    > $exp_dir/classifier/logistic-regression.log

  echo "Finished stage 8."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Runtime: < 10s
if [ $stage -eq 9 ]; then
  echo "#### STAGE 9: Calculating results. ####"

  ./local/compute_results.py \
    --classification-file $exp_dir/results/classification \
    --output-file $exp_dir/results/results \
    --language-list "$GP_ENROLL_LANGUAGES" \
    2>$exp_dir/results/compute_results.log

  echo "Finished stage 9."
fi
