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
\t       --stage=INT\t\tStage from which to start\n
\t       --run-all=(false|true)\tWhether to run all stages\n
\t       \t\t\tor just the specified one\n
\t       --experiment=STR\tExperiment name (also name of directory \n
\t       \t\t\twhere all files will be stored).\n
\t       \t\t\tDefault: 'baseline'.\n\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Default option values
EXP_NAME="/baseline"
stage=-1
run_all=false

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --run-all=*)
  run_all=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --stage=*)
  stage=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --experiment=*)
  EXP_NAME=/`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

echo -e $usage

if [ $stage -eq -1 ]; then
  if [ "$run_all" = true ]; then
    echo "No stage specified and --run-all=true, running all stages."
    stage=0
  else
    echo "No stage specified and --run-all=false, not running any stages."
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

if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
  if [[ $(whichMachine) == cluster* ]]; then
    echo "Conda environment not activated, sourcing ~/.bashrc and activating the 'lid' env."
    source ~/.bashrc
    conda activate lid || exit
  elif [[ $(whichMachine) == dice* ]]; then
    echo "Conda environment not activated, trying to activate it."
    source activate lid || exit
  else
    echo "Conda environment not activated, trying to activate it."
    conda activate lid || exit
  fi
else
  echo "Conda environment '$CONDA_DEFAULT_ENV' active."
fi

[ -f conf/general_config.sh ] && source ./conf/general_config.sh \
  || echo "conf/general_config.sh not found or contains errors!"

[ -f conf/user_specific_config.sh ] && source ./conf/user_specific_config.sh \
  || echo "conf/user_specific_config.sh not found, create it by cloning " + \
          "conf/user_specific_config-example.sh"

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."


# CHECKING FOR AND INSTALLING REQUIRED TOOLS:
#  This recipe requires shorten (3.6.1) and sox (14.3.2).
#  If they are not found, the local/gp_install.sh script will install them.
local/gp_check_tools.sh $PWD path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

DATADIR="${DATADIR}${EXP_NAME}"
echo $DATADIR

if [[ $(whichMachine) == cluster* ]]; then
  home_prefix=$HOME/lid

  train_data=$home_prefix/train
  enroll_data=$home_prefix/enroll
  eval_data=$home_prefix/eval
  test_data=$home_prefix/test
  log_dir=$home_prefix/log
  mfccdir=$home_prefix/mfcc
  vaddir=$home_prefix/mfcc
  feat_dir=$home_prefix/x_vector_features
  nnet_train_data=$home_prefix/nnet_train_data
  nnet_dir=$home_prefix/nnet
  exp_dir=$home_prefix/exp
else
  train_data=$DATADIR/train
  enroll_data=$DATADIR/enroll
  eval_data=$DATADIR/eval
  test_data=$DATADIR/test
  log_dir=$DATADIR/log
  mfccdir=$DATADIR/mfcc
  vaddir=$DATADIR/mfcc
  feat_dir=$DATADIR/x_vector_features
  nnet_train_data=$train_data/combined_no_sil
  nnet_dir=$DATADIR/nnet
  exp_dir=$DATADIR/exp
fi

# Set the languages that will actually be processed
GP_LANGUAGES="TA WU"

echo "Running with languages: ${GP_LANGUAGES}"


# The most time-consuming stage: Converting SHNs to WAVs. Should be done only once; 
# then, this script can be run from stage 0 onwards.
if [ $stage -eq 42 ]; then
  echo "#### SPECIAL STAGE 42: Converting all SHN files to WAV files. ####"
  ./local/make_wavs.sh \
    --corpus-dir=$GP_CORPUS \
    --wav-dir=$HOME/lid/wav \
    --lang-map=$PWD/conf/lang_codes.txt \
    --languages="$GP_LANGUAGES"
fi

# Preparing lists of utterances (and a couple other auxiliary lists) based 
# on the train/enroll/eval/test splitting. The lists refer to the WAVs 
# generated in the previous stage.
if [ $stage -eq 0 ]; then
  # NOTE: The wav-dir as it is right now only works in the cluster!
  echo "#### STAGE 0: Organising speakers into sets. ####"
  ./local/gp_data_organise.sh \
    --config-dir=$PWD/conf \
    --corpus-dir=$GP_CORPUS \
    --wav-dir=/mnt/mscteach_home/s1513472/lid/wav \
    --languages="$GP_LANGUAGES" \
    --data-dir=$DATADIR \
    || exit 1;
  
  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Make MFCCs and compute the energy-based VAD for each dataset
if [ $stage -eq 1 ]; then
  echo "#### STAGE 1: MFCC and VAD. ####"
  
  for name in train enroll eval test; do
    (
    steps/make_mfcc.sh \
      --write-utt2num-frames false \
      --mfcc-config conf/mfcc.conf \
      --nj $MAXNUMJOBS \
      --cmd "$preprocess_cmd" \
      $DATADIR/${name} \
      $log_dir/make_mfcc \
      $mfccdir
		
    # Have to calculate this separately, since make_mfcc.sh isn't writing properly
		utils/data/get_utt2num_frames.sh $DATADIR/${name}
    utils/fix_data_dir.sh $DATADIR/${name}

    ./local/compute_vad_decision.sh \
      --nj $MAXNUMJOBS \
      --cmd "$preprocess_cmd" \
      $DATADIR/${name} \
      $log_dir/make_vad \
      $vaddir

    utils/fix_data_dir.sh $DATADIR/${name}
    ) > $log_dir/mfcc_${name} & 
  done
  wait;

  utils/fix_data_dir.sh $train_data
  utils/fix_data_dir.sh $enroll_data
  utils/fix_data_dir.sh $eval_data
  utils/fix_data_dir.sh $test_data
  
  if [ "$run_all" = true ]; then
    # NOTE this is set to 2 since we're skipping stage 2 at the moment.
    stage=`expr $stage + 2`
  else
    exit
  fi
fi

# TO-DO: Add data augmentation with MUSAN as stage 2?

# Now we prepare the features to generate examples for xvector training.
if [ $stage -eq 3 ]; then
  # NOTE silence not being removed
  echo "#### STAGE 3: Preprocessing for X-vector training examples. ####"
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/prepare_feats_for_egs.sh \
    --nj $MAXNUMJOBS \
    --cmd "$preprocess_cmd" \
    $train_data \
    $nnet_train_data \
    $feat_dir

	utils/data/get_utt2num_frames.sh $nnet_train_data
  utils/fix_data_dir.sh $nnet_train_data

  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
	echo "Removing short features..."
  min_len=500
  mv $nnet_train_data/utt2num_frames $nnet_train_data/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $nnet_train_data/utt2num_frames.bak > $nnet_train_data/utt2num_frames
  utils/filter_scp.pl $nnet_train_data/utt2num_frames $nnet_train_data/utt2spk > $nnet_train_data/utt2spk.new
  mv $nnet_train_data/utt2spk.new $nnet_train_data/utt2spk
  utils/fix_data_dir.sh $nnet_train_data
	echo "Done"

  # Now we're ready to create training examples.
  #utils/fix_data_dir.sh $nnet_train_data
  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

#NOTE main things we need to work on are the num-repeats and num-jobs parameters
if [ $stage -eq 4 ]; then
  echo "#### STAGE 4: Training the X-vector DNN. ####"
  ./local/run_xvector.sh \
    --stage 4 \
    --train-stage -1 \
    --data $nnet_train_data \
    --nnet-dir $nnet_dir \
    --egs-dir $nnet_dir/egs

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 3`
  else
    exit
  fi
fi

if [ $stage -eq 7 ]; then
  echo "#### STAGE 7: Extracting X-vectors from the trained DNN. ####"

  if [[ $(whichMachine) == cluster* ]]; then
    use_gpu=true
  else
    use_gpu=false
  fi

  # X-vectors for training the classifier
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $enroll_data \
    $exp_dir/xvectors_enroll &

  # X-vectors for end-to-end evaluation
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $eval_data \
    $exp_dir/xvectors_eval &

  # X-vectors for testing (final evaluation)
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $test_data \
    $exp_dir/xvectors_test &

  wait;
  echo "Done"

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Using logistic regression as a classifier (adapted from egs/lre07,
# described in https://arxiv.org/pdf/1804.05000.pdf)
if [ $stage -eq 8 ]; then
  echo "#### STAGE 8: Training logistic regression classifier and classifying test utterances. ####"
  
  # Make language-int map (essentially just indexing the languages 0 to L)
  langs=($GP_LANGUAGES)
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
    --train-utt2lang $DATADIR/enroll/utt2lang \
    --test-utt2lang $DATADIR/eval/utt2lang \
    --languages conf/test_languages.list \
    > $exp_dir/classifier/logistic-regression.log

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

if [ $stage -eq 9 ]; then
  echo "#### STAGE 9: Calculating results. ####"

  python ./local/compute_results.py \
    --classification-file $exp_dir/results/classification \
    --output-file $exp_dir/results/results \
    --language-list "$GP_LANGUAGES" \
    2>$exp_dir/results/compute_results.log
fi
