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
\t       --config=FILE\tConfig file with all kinds of options,\n
\t       \t\t\tsee conf/exp_default.conf for an example.\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Default option values
exp_name="baseline"
stage=-1
run_all=false
config=NONE
num_epochs=3
feature_type=mfcc
skip_nnet_training=false
use_model_from=NONE
use_data_augmentation=false
use_rirs_augmentation=false
use_preprocessed=false
shorten_data=true
evaluation_length=30
test_length=30
enrollment_length=30
use_dnn_egs_from=
aug_expt=
GP_CORPUS=

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config=*)
  config=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
echo -e $usage

# Run from the home directory
home_dir=~/language-ident-from-speech/gp-xvectors-recipe
cd $home_dir
conf_dir=$home_dir/conf
exp_conf_dir=$conf_dir/exp_configs

config="${config}.conf"
if [ "$config" == "NONE" ] || [ ! -f $exp_conf_dir/${config} ]; then
  echo "Configuration file '${config}' not found for this experiment in $exp_conf_dir."
  exit 1;
fi

# Source some variables from the experiment-specific config file
source $exp_conf_dir/$config || echo "Problems sourcing the experiment config file: $exp_conf_dir/$config"

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
if [[ $(whichMachine) != "paul" ]]; then
  ./local/gp_check_tools.sh $home_dir path.sh || exit 1;
fi

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

root_data_dir=$DATADIR
rirs_dir=$root_data_dir/RIRS_NOISES
musan_dir=$root_data_dir/musan

check_user_continue(){
  echo "Experiment $1 already found.\n"
  read -p "Do you want to continue (repeat expt)? [y/n]" -r
  # Avoid using negated form since that doesn't work properly in some shells
  if [[ $REPLY =~ ^[Yy].*$ ]]
  then
    echo "Continuing..."
  else
    echo "Exiting"
    exit
  fi
}
is_second=false
is_third=false

if [ -d $root_data_dir/$exp_name ] && [ $stage -eq 1 ]; then
  #check_user_continue $exp_name;
  if [ -d $root_data_dir/${exp_name}_2 ] && [ $stage -eq 1 ]; then
    #check_user_continue ${exp_name}_2;
    if [ -d $root_data_dir/${exp_name}_3 ]; then
      echo "Already repeated 3x"
      exit
    else
      # Exp #3 directory doesn't exist
      exp_name=${exp_name}_3
      is_third=true
    fi
  else
    # Exp #2 directory doesn't exist
    exp_name=${exp_name}_2
    is_second=true
  fi
fi

# This step was removed when running on my local machine
:<<"EOF"
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
EOF

home_prefix=$root_data_dir/$exp_name
train_data=$home_prefix/train
enroll_data=$home_prefix/enroll
eval_data=$home_prefix/eval_${evaluation_length}s
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
  home_prefix=$root_data_dir/$use_dnn_egs_from
  echo "Using preprocessed data	from: $home_prefix"

  if [ ! -d $home_prefix ]; then
    echo "ERROR: directory containging preprocessed data not found: '$home_prefix'"
    exit 1
  fi

  train_data=$home_prefix/train
  enroll_data=$home_prefix/enroll
  eval_data=$home_prefix/eval_${evaluation_length}s
  test_data=$home_prefix/test
  nnet_train_data=$home_prefix/nnet_train_data
  preprocessed_data_dir=$root_data_dir/$use_dnn_egs_from
fi

if [ "$is_second" = true ]; then
  old_expt_dir=$root_data_dir/${use_model_from}_2
elif [ "$is_third" = true ]; then
  old_expt_dir=$root_data_dir/${use_model_from}_3
else
  old_expt_dir=$root_data_dir/${use_model_from}
fi


# Check any requested model exists
if [ -f $old_expt_dir/nnet/final.raw ] && [ "$skip_nnet_training" = true ]; then
  nnet_dir=$old_expt_dir/nnet
  eval_data=$old_expt_dir/eval_${evaluation_length}s
  echo "Model found!"
  echo "The nnet directory is $nnet_dir"
  GP_TRAIN_LANGUAGES="SKIP"
  mkdir -p $exp_dir
  # Copy old evaluation X-vectors since they won't change.
  cp -r $old_expt_dir/exp/xvectors_eval_30s $exp_dir/xvectors_eval_30s
  cp -r $old_expt_dir/exp/xvectors_eval_10s $exp_dir/xvectors_eval_10s
  cp -r $old_expt_dir/exp/xvectors_eval_3s $exp_dir/xvectors_eval_3s

  GP_EVAL_LANGUAGES="SKIP"
elif [ ! -d $root_data_dir/$use_model_from/nnet ] && [ "$skip_nnet_training" = true ]; then
  if [ -f $nnet_dir/final.raw ]; then
    echo "Using own model in $nnet_dir"
  else
    echo "Model not found in $root_data_dir/$use_model_from/nnet"
    exit
  fi

else
  echo "Training model as normal"
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
  if [ "$is_second" = true ]; then
    aug_expt=${aug_expt}_2
  elif [ "$is_third" = true ]; then
    aug_expt=${aug_expt}_3
  fi
  echo "Using clean data from augmented experiment $aug_expt"
  if [ -d $root_data_dir/$aug_expt ]; then
    prefix=$root_data_dir/$aug_expt
    train_data=$prefix/train_clean
    enroll_data=$prefix/enroll
    eval_data=$prefix/eval_${evaluation_length}s
    test_data=$prefix/test
  else
    echo "Error: augmented experiment directory not found"
    exit 1
  fi
  # Skip to stage 3 since data already exists
  if [ "$run_all" = true ]; then
    if [ $stage -lt 3 ]; then
      stage=3
    fi
  else
    exit
  fi
else
  # Check if using data augmentation (and not clean, then set training directory)
  if [ "$use_data_augmentation" = true ] || [ "$use_rirs_augmentation" = true ]; then
    train_data=$home_prefix/train_aug
  else
    echo "No augmentation done"
  fi
fi

DATADIR="${root_data_dir}/$exp_name"
mkdir -p $DATADIR
mkdir -p $DATADIR/log
echo "The experiment directory is: $DATADIR"
ev=${evaluation_length}s

# Preparing lists of utterances (and a couple other auxiliary lists) based
# on the train/enroll/eval/test splitting. The lists refer to the WAVs
# generated in the previous stage.
# Runtime: Under 5 mins

if [ "$use_preprocessed" = true ] && [ $stage -eq 1 ]; then
  echo "Setting up preprocessed data"
  processed_dir=$root_data_dir/all_preprocessed
  ./local/prep_preprocessed.sh \
    --config-dir=$conf_dir \
    --processed-dir=$processed_dir \
    --data-augmentation=$use_data_augmentation \
    --rirs-augmentation=$use_rirs_augmentation \
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
    --shorten-data=$shorten_data \
    > $DATADIR/setup_summary.txt
  echo "Finished running"
fi

if [ "$run_all" = true ] && [ "$skip_nnet_training" = true ]; then
  if [ $stage -lt 7 ]; then
    stage=7
  fi
elif [ "$run_all" = true ] && [ "$use_preprocessed" = true ]; then
  if [ $stage -lt 3 ]; then
    stage=3
  fi
elif [ "$run_all" = true ]; then
  stage=1
else
  exit
fi

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
    mv $enroll_data/wav.scp.temp $enroll_daa/wav.scp > $enroll_data/wav.scp.temp
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

    # NB: The MUSAN corpus was later dropped, so the code here was not usually run (used the preprocessed scripts instead)
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
  echo "#### STAGE 3: Preprocessing for X-vector training examples. ####"
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  ./local/prepare_feats_for_egs.sh \
    --nj 40 \
    --cmd "$preprocess_cmd" \
    $train_data \
    $nnet_train_data \
    $feat_dir

	utils/data/get_utt2num_frames.sh $nnet_train_data
  utils/fix_data_dir.sh $nnet_train_data

  # Removes utterances shorter than 3 seconds. Unnecessary when the shortening was done beforehand.
	#echo "Removing short features..."
  #min_len=300
  #mv $nnet_train_data/utt2num_frames $nnet_train_data/utt2num_frames.bak
  #awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $nnet_train_data/utt2num_frames.bak > $nnet_train_data/utt2num_frames
  #utils/filter_scp.pl $nnet_train_data/utt2num_frames $nnet_train_data/utt2spk > $nnet_train_data/utt2spk.new
  #mv $nnet_train_data/utt2spk.new $nnet_train_data/utt2spk
  #utils/fix_data_dir.sh $nnet_train_data

  echo "Finished stage 3."

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Runtime: ~24 hours with 7 epochs
if [ $stage -ge 4 ] && [ $stage -le 6 ]; then
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
      --stage $stage \
      --train-stage -1 \
      --num-epochs $num_epochs \
      --max-num-jobs $MAXNUMJOBS \
      --data $nnet_train_data \
      --nnet-dir $nnet_dir \
      --egs-dir $nnet_dir/egs
  fi

  echo "Finished stage 4."

  if [ "$run_all" = true ]; then
    stage=7
  else
    exit
  fi
fi

# Runtime: ~1:05h
if [ $stage -eq 7 ]; then
  echo "#### STAGE 7: Extracting X-vectors from the trained DNN. ####"

  if [[ $(whichMachine) == cluster* ]]; then
    use_gpu=true
    nj=$MAXNUMJOBS
  else
    if [[ $(whichMachine) == paul ]]; then
      use_gpu=wait
      nj=1
    else
      nj=$MAXNUMJOBS
      use_gpu=false
    fi
  fi
  remove_nonspeech=false
  if [ ! -d $exp_dir/xvectors_enroll ]; then
    # X-vectors for training the classifier
    ./local/extract_xvectors.sh \
      --cmd "$extract_cmd --mem 6G" \
      --use-gpu $use_gpu \
      --nj $nj \
      --stage 0 \
      --remove-nonspeech "$remove_nonspeech" \
      $nnet_dir \
      $enroll_data \
      $exp_dir/xvectors_enroll &
  fi
  if [ ! -d $exp_dir/xvectors_eval_${ev} ]; then
    # X-vectors for end-to-end evaluation
    ./local/extract_xvectors.sh \
      --cmd "$extract_cmd --mem 6G" \
      --use-gpu $use_gpu \
      --nj $nj \
      --stage 0 \
      --remove-nonspeech "$remove_nonspeech" \
      $nnet_dir \
      $eval_data \
      $exp_dir/xvectors_eval_${ev} &
  fi

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
    stage=8
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

  if [ ! -d $exp_dir/classifier ]; then

    mkdir -p $exp_dir/classifier

    # Training the log reg model and classifying test set samples
    ./local/run_logistic_regression.sh \
      --prior-scale 0.70 \
      --conf conf/logistic-regression.conf \
      --train-dir $exp_dir/xvectors_enroll \
      --test-dir $exp_dir/xvectors_eval_${ev} \
      --model-dir $exp_dir/classifier \
      --classification-file $exp_dir/results/classification_${ev} \
      --train-utt2lang $enroll_data/utt2lang \
      --test-utt2lang $eval_data/utt2lang \
      --languages conf/test_languages.list \
      > $exp_dir/classifier/logistic-regression_${ev}.log
  fi

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
    --classification-file $exp_dir/results/classification_${ev} \
    --output-file $exp_dir/results/results_${ev} \
    --language-list "$GP_ENROLL_LANGUAGES" \
    2>$exp_dir/results/compute_results_${ev}.log

  echo "Finished stage 9."
fi
if [ $(ls $exp_dir/results | wc -l) -eq 3 ]; then
  echo "The experiment $exp_name finished correctly" #| mail -v -s "$exp_name" myemail@gmail.com
else
  echo "The experiment $exp_name did not finish correctly" #| mail -v -s "$exp_name" myemail@gmail.com
fi
