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


echo $'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
       This shell script runs the GlobalPhone+X-vectors recipe.
       Use like this: ./run.sh stagenumber
       or don\'t provide stage number to run the whole recipe.
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'

if [ $# -eq 0 ]; then
	echo "No stage specified; assuming stage 0 and running the entire recipe from the beginning."
  stage=0
  run_all=true
else
  if [ $# -eq 1 ]; then
    echo "Doing stage $1"
    stage=$1
    echo "Only a single stage will be run"
    run_all=false
  fi

  if [ $# -eq 2 ]; then
  	echo "Doing stage $1"
  	stage=$1
    shift
    echo "Running entire thing: $1"
    run_all=$1
  fi
fi

# Check that the boolean argument is valid
if [ "$run_all" = false ]; then
  false_test="False"
else
  false_test="True"
fi

if [ "$run_all" = true ]; then
  true_test="True"
else
  true_test="False"
fi

if [[ $false_test == "True" && $true_test == "False" ]]; then
  echo "Invalid argument given for boolean. Should be <true|false>"
  exit 1
fi

if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
	echo "Seems like your conda environment is not activated. Use: source activate ENVNAME."
	exit
else
	echo "Conda environment '$CONDA_DEFAULT_ENV' active."
fi

[ -f conf/general_config.sh ] && source ./conf/general_config.sh \
	|| echo "conf/general_config.sh not found or contains errors!"

[ -f conf/user_specific_config.sh ] && source ./conf/user_specific_config.sh \
	|| echo "conf/user_specific_config.sh not found, create it by cloning " + \
					"conf/user_specific_config-example.sh"

[ -f helper_functions.sh ] && source ./helper_functions.sh \
  || echo "helper_functions.sh not found. Won't be able to set environment variables and similar."

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."


# CHECKING FOR AND INSTALLING REQUIRED TOOLS:
#  This recipe requires shorten (3.6.1) and sox (14.3.2).
#  If they are not found, the local/gp_install.sh script will install them.
local/gp_check_tools.sh $PWD path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }


if [[ $(whichMachine) == cluster* ]]; then
  home_prefix=$HOME/lid

  train_data=$home_prefix/train
  eval_test_dir=$home_prefix/eval_test
  eval_enroll_dir=$home_prefix/eval_enroll
  log_dir=$home_prefix/log
  mfccdir=$home_prefix/mfcc
  vaddir=$home_prefix/mfcc
  feat_dir=$home_prefix/x_vector_features
  nnet_train_data=$home_prefix/nnet_train_data
  nnet_dir=$home_prefix/nnet
  exp_dir=$home_prefix/exp
else
  train_data=$DATADIR/train
  eval_test_dir=$DATADIR/eval_test
  eval_enroll_dir=$DATADIR/eval_enroll
  log_dir=$DATADIR/log
  mfccdir=$DATADIR/mfcc
  vaddir=$DATADIR/mfcc
  feat_dir=$DATADIR/x_vector_features
  nnet_train_data=$train_data/combined_no_sil
  nnet_dir=$DATADIR/nnet
  exp_dir=$DATADIR/exp
fi


export GP_LANGUAGES="GE SW KO" # Set the languages that will actually be processed

echo "Running with languages: ${GP_LANGUAGES}"

# The following data preparation step actually converts the audio files from
# shorten to WAV to take out the empty files and those with compression errors.
if [ $stage -eq 0 ]; then
  echo "#### STAGE 0: Data preparation. ####"
	local/gp_data_prep.sh \
		--config-dir=$PWD/conf \
		--corpus-dir=$GP_CORPUS \
		--languages="$GP_LANGUAGES" \
		--data-dir=$DATADIR \
		|| exit 1;

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

# Now make MFCC features.
if [ $stage -eq 1 ]; then
  echo "#### STAGE 1: MFCC and VAD. ####"
  # Make MFCCs and compute the energy-based VAD for each dataset
  
  for name in train eval_test eval_enroll; do
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
  done
	#utils/combine_data.sh --extra-files 'utt2num_frames' $DATADIR/
  utils/fix_data_dir.sh $train_data
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

  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $eval_enroll_dir \
    $exp_dir/xvectors_eval_enroll &

  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $eval_test_dir \
    $exp_dir/xvectors_eval_test &

  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $train_data \
    $exp_dir/xvectors_train &

  wait;
  echo "Done"

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

if [ $stage -eq 8 ]; then
  echo "#### STAGE 8: Building PLDA model. ####"

  # Compute the mean vector for centering the evaluation xvectors.
  $plda_cmd $exp_dir/xvectors_eval_enroll/log/compute_mean.log \
    ivector-mean scp:$exp_dir/xvectors_eval_enroll/xvector.scp \
    $exp_dir/xvectors_eval_enroll/mean.vec || exit 1;

  echo "Decreasing dimensionality with LDA before doing PLDA"
  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=150
  $plda_cmd $exp_dir/xvectors_train/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:${exp_dir}/xvectors_train/xvector.scp ark:- |" \
    ark:$train_data/utt2lang $exp_dir/xvectors_train/transform.mat || exit 1;

  echo "Training PLDA model"
  # Train an out-of-domain PLDA model.
  $plda_cmd $exp_dir/xvectors_train/log/plda.log \
    ivector-compute-plda ark:$train_data/lang2utt \
    "ark:ivector-subtract-global-mean scp:${exp_dir}/xvectors_train/xvector.scp ark:- | transform-vec ${exp_dir}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
    $exp_dir/xvectors_train/plda || exit 1;

  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi

if [ $stage -eq 9 ]; then
  echo "#### STAGE 9: Get results from PLDA model ####"
  # Generate trials
  python ./local/get_trials.py --test-dir $eval_test_dir

  # Get results using the out-of-domain PLDA model.
  $plda_cmd $exp_dir/scores/log/eval_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:$exp_dir/xvectors_eval_test/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 $exp_dir/xvectors_train/plda - |" \
    "ark:ivector-mean ark:${eval_enroll_dir}/lang2utt scp:${exp_dir}/xvectors_eval_enroll/xvector.scp ark:- | ivector-subtract-global-mean ${exp_dir}/xvectors_eval_enroll/mean.vec ark:- ark:- | transform-vec ${exp_dir}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean ${exp_dir}/xvectors_eval_enroll/mean.vec scp:${exp_dir}/xvectors_eval_test/xvector.scp ark:- | transform-vec ${exp_dir}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '${eval_test_dir}/trials_all' | cut -d\  --fields=1,2 |" $exp_dir/scores/lang_eval_scores || exit 1;
  
  python ./local/classify_scores.py --scores-dir $exp_dir/scores
  exit
  
  # pooled_eer=$(paste ${eval_test_dir}/trials_all ${exp_dir}/scores/lang_eval_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  # echo "Using Out-of-Domain PLDA, EER: Pooled ${pooled_eer}%" #, Tagalog ${tgl_eer}%, Cantonese ${yue_eer}%"
  # exit
  # utils/filter_scp.pl $sre16_trials_tgl ${exp_dir}/scores/sre16_eval_scores > ${exp_dir}/scores/sre16_eval_tgl_scores
  # utils/filter_scp.pl $sre16_trials_yue ${exp_dir}/scores/sre16_eval_scores > ${exp_dir}/scores/sre16_eval_yue_scores
  # pooled_eer=$(paste $sre16_trials ${exp_dir}/scores/sre16_eval_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  # tgl_eer=$(paste $sre16_trials_tgl ${exp_dir}/scores/sre16_eval_tgl_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  # yue_eer=$(paste $sre16_trials_yue ${exp_dir}/scores/sre16_eval_yue_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  # echo "Using Out-of-Domain PLDA, EER: Pooled ${pooled_eer}%, Tagalog ${tgl_eer}%, Cantonese ${yue_eer}%"
  
  # EER: Pooled 11.73%, Tagalog 15.96%, Cantonese 7.52%
  # For reference, here's the ivector system from ../v1:
  # EER: Pooled 13.65%, Tagalog 17.73%, Cantonese 9.61%
fi
