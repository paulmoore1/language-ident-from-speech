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
	echo "No stage specified; assuming stage 0 and running the recipe from the beginning."
  stage=0
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

# Don't need language models for LID.
# GP_LM=$PWD/language_models

TRAINDIR=$DATADIR/train
EVALDIR=$DATADIR/eval
UNLABELLEDDIR=$DATADIR/unlabelled
FEATDIR=$DATADIR/x_vector_features
EXPDIR=$DATADIR/exp
mfccdir=$DATADIR/mfcc
vaddir=$DATADIR/mfcc
nnet_dir=$DATADIR/nnet

export GP_LANGUAGES="CR TU" # Set the languages that will actually be processed

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
	#local/gp_dict_prep.sh --config-dir $PWD/conf $GP_CORPUS $GP_LANGUAGES || exit 1;
  if [ "$run_all" = true ]; then
    stage=`expr $stage + 1`
  else
    exit
  fi
fi
# TEMP

# Now make MFCC features.
if [ $stage -eq 1 ]; then
  echo "#### STAGE 1: MFCC and VAD. ####"
  # Make MFCCs and compute the energy-based VAD for each dataset
  #TODO is this doing anything important?
  #if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $mfccdir/storage ]; then
  #  utils/create_split_dir.pl \
  #    /export/b{14,15,16,17}/$USER/kaldi-data/egs/sre16/v2/xvector-$(date +'%m_%d_%H_%M')/mfccs/storage $mfccdir/storage
  #fi
	# temporarily set to false, isn't doing it right
  for name in train eval; do
    steps/make_mfcc.sh \
      --write-utt2num-frames false \
      --mfcc-config conf/mfcc.conf \
      --nj $MAXNUMJOBS \
      --cmd "$train_cmd" \
      $DATADIR/${name} \
      $DATADIR/log/make_mfcc \
      $mfccdir
			# Have to calculate this separately, since make_mfcc.sh isn't writing properly
		utils/data/get_utt2num_frames.sh $DATADIR/${name}
    utils/fix_data_dir.sh $DATADIR/${name}

    ./local/compute_vad_decision.sh \
      --nj $MAXNUMJOBS \
      --cmd "$train_cmd" \
      $DATADIR/${name} \
      $EXPDIR/make_vad \
      $vaddir

    utils/fix_data_dir.sh $DATADIR/${name}
  done
	#utils/combine_data.sh --extra-files 'utt2num_frames' $DATADIR/
  utils/fix_data_dir.sh $TRAINDIR
  if [ "$run_all" = true ]; then
    # NOTE this is set to 2 since we're skipping stage 2 at the moment.
    stage=`expr $stage + 2`
  else
    exit
  fi
fi


:<<'MUSAN'
#In order to fix this, we need the MUSAN corpus - currently skipping augmentation
# In this section, we augment the training data with reverberation,
# noise, music, and babble, and combined it with the clean data.
# The combined list will be used to train the xvector DNN.  The SRE
# subset will be used to train the PLDA model.
if [ $stage -eq 2 ]; then
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' $TRAINDIR/utt2num_frames > $TRAINDIR/reco2dur

  if [ ! -d "RIRS_NOISES" ]; then
    # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
    wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
    unzip rirs_noises.zip
  fi

  # Make a version with reverberated speech
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the SWBD+SRE list.  Note that we don't add any
  # additive noise here.
  python steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 8000 \
    $TRAINDIR $TRAINDIR/reverb
  cp $TRAINDIR/vad.scp $TRAINDIR/reverb
  utils/copy_data_dir.sh --utt-suffix "-reverb" $TRAINDIR/reverb $TRAINDIR/reverb.new
  rm -rf $TRAINDIR/reverb
  mv $TRAINDIR/reverb.new $TRAINDIR/reverb

  # Prepare the MUSAN corpus, which consists of music, speech, and noise
  # suitable for augmentation.
  local/make_musan.sh /export/corpora/JHU/musan $DATADIR

  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh $DATADIR/musan_${name}
    mv $DATADIR/musan_${name}/utt2dur $DATADIR/musan_${name}/reco2dur
  done

  # Augment with musan_noise
  python steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "data/musan_noise" $TRAINDIR $TRAINDIR/noise
  # Augment with musan_music
  python steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "data/musan_music" $TRAINDIR $TRAINDIR/music
  # Augment with musan_speech
  python steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "data/musan_speech" $TRAINDIR $TRAINDIR/babble

  # Combine reverb, noise, music, and babble into one directory.
  utils/combine_data.sh $TRAINDIR/aug $TRAINDIR/reverb $TRAINDIR/noise $TRAINDIR/music $TRAINDIR/babble

  # Take a random subset of the augmentations (128k is somewhat larger than twice
  # the size of the SWBD+SRE list)
  utils/subset_data_dir.sh $TRAINDIR/aug 128000 $TRAINDIR/aug_128k
  utils/fix_data_dir.sh $TRAINDIR/aug_128k

  # Make MFCCs for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj $MAXNUMJOBS --cmd "$train_cmd" \
    $TRAINDIR/aug_128k exp/make_mfcc $mfccdir

  # Combine the clean and augmented SWBD+SRE list.  This is now roughly
  # double the size of the original clean list.
  utils/combine_data.sh $TRAINDIR/combined $TRAINDIR/aug_128k $TRAINDIR

  #TODO not quite sure how to do this with our setup
  # Filter out the clean + augmented portion of the SRE list.  This will be used to
  # train the PLDA model later in the script.
  CLEANDIR = $DATADIR/clean
  utils/copy_data_dir.sh $TRAINDIR/combined $CLEANDIR/combined
  utils/filter_scp.pl data/sre/spk2utt data/swbd_sre_combined/spk2utt | utils/spk2utt_to_utt2spk.pl > data/sre_combined/utt2spk
  utils/fix_data_dir.sh data/sre_combined
fi
MUSAN

# Now we prepare the features to generate examples for xvector training.
if [ $stage -eq 3 ]; then
  # NOTE silence not being removed
  echo "#### STAGE 3: Preprocessing for X-vector training examples. ####"
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/prepare_feats_for_egs.sh \
    --nj $MAXNUMJOBS \
    --cmd "$train_cmd" \
    $TRAINDIR \
    $TRAINDIR/combined_no_sil \
    $FEATDIR

		# !!!TODO change to $TRAINDIR/combined when data augmentation works
	utils/data/get_utt2num_frames.sh $TRAINDIR/combined_no_sil
  utils/fix_data_dir.sh $TRAINDIR/combined_no_sil

  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
	echo "Removing short features..."
  min_len=500
  mv $TRAINDIR/combined_no_sil/utt2num_frames $TRAINDIR/combined_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $TRAINDIR/combined_no_sil/utt2num_frames.bak > $TRAINDIR/combined_no_sil/utt2num_frames
  utils/filter_scp.pl $TRAINDIR/combined_no_sil/utt2num_frames $TRAINDIR/combined_no_sil/utt2spk > $TRAINDIR/combined_no_sil/utt2spk.new
  mv $TRAINDIR/combined_no_sil/utt2spk.new $TRAINDIR/combined_no_sil/utt2spk
  utils/fix_data_dir.sh $TRAINDIR/combined_no_sil
	echo "Done"

  #NOTE: This step is unnecessary since we need several utterances per language (which we have)
  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.
	#echo "Removing speakers with < 8 utterances..."
  #min_num_utts=8
  #awk '{print $1, NF-1}' $TRAINDIR/combined_no_sil/spk2utt > $TRAINDIR/combined_no_sil/spk2num
  #awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' $TRAINDIR/combined_no_sil/spk2num | utils/filter_scp.pl - $TRAINDIR/combined_no_sil/spk2utt > $TRAINDIR/combined_no_sil/spk2utt.new
  #mv $TRAINDIR/combined_no_sil/spk2utt.new $TRAINDIR/combined_no_sil/spk2utt
  #utils/spk2utt_to_utt2spk.pl $TRAINDIR/combined_no_sil/spk2utt > $TRAINDIR/combined_no_sil/utt2spk
	#echo "Done"
  #utils/filter_scp.pl $TRAINDIR/combined_no_sil/utt2spk $TRAINDIR/combined_no_sil/utt2num_frames > $TRAINDIR/combined_no_sil/utt2num_frames.new
  #mv $TRAINDIR/combined_no_sil/utt2num_frames.new $TRAINDIR/combined_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  #utils/fix_data_dir.sh $TRAINDIR/combined_no_sil
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
    --data $TRAINDIR/combined_no_sil \
    --nnet-dir $nnet_dir \
    --egs-dir $nnet_dir/egs
    #NOTE not sure if the stage variable will be updated by the running of the xvector
  if [ "$run_all" = true ]; then
    stage=`expr $stage + 3`
  else
    exit
  fi
fi

if [ $stage -eq 7 ]; then
  echo "#### STAGE 7: Extracting X-vectors from the trained DNN. ####"

  ./local/extract_xvectors.sh \
    --cmd "$train_cmd --mem 6G" \
    --use-gpu false \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $UNLABELLEDDIR \
    $EXPDIR/xvectors_unlabelled

  ./local/extract_xvectors.sh \
    --cmd "$train_cmd --mem 6G" \
    --use-gpu false \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $EVALDIR \
    $EXPDIR/xvectors_eval

  ./local/extract_xvectors.sh \
    --cmd "$train_cmd --mem 6G" \
    --use-gpu false \
    --nj $MAXNUMJOBS \
    $nnet_dir \
    $TRAINDIR \
    $EXPDIR/xvectors_train
    if [ "$run_all" = true ]; then
      stage=`expr $stage + 1`
    else
      exit
    fi
fi

if [ $stage -eq 8 ]; then
  # Compute the mean vector for centering the evaluation xvectors.
  $train_cmd $EXPDIR/xvectors_unlabelled/log/compute_mean.log \
    ivector-mean scp:$EXPDIR/xvectors_unlabelled/xvector.scp \
    $EXPDIR/xvectors_unlabelled/mean.vec || exit 1;

  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=150
  $train_cmd $EXPDIR/xvectors_train/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:${EXPDIR}/xvectors_train/xvector.scp ark:- |" \
    ark:$TRAINDIR/utt2spk $EXPDIR/xvectors_train/transform.mat || exit 1;

  # Train an out-of-domain PLDA model.
  $train_cmd $EXPDIR/xvectors_train/log/plda.log \
    ivector-compute-plda ark:$TRAINDIR/spk2utt \
    "ark:ivector-subtract-global-mean scp:${EXPDIR}/xvectors_train/xvector.scp ark:- | " \
    "transform-vec ${EXPDIR}/xvectors_train/transform.mat ark:- ark:- | " \
    "ivector-normalize-length ark:-  ark:- |" \
    $EXPDIR/xvectors_train/plda || exit 1;

    if [ "$run_all" = true ]; then
      stage=`expr $stage + 1`
    else
      exit
    fi

fi

if [ $stage -eq 9 ]; then
  # Get results using the out-of-domain PLDA model.
  $train_cmd $EXPDIR/scores/log/eval_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:$EXPDIR/xvectors_eval/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 ${EXPDIR}/xvectors_train/plda - |" \
    "ark:ivector-mean ark:${EVALDIR}/spk2utt scp:${EXPDIR}/xvectors_eval/xvector.scp ark:- | " \
    "transform-vec ${EXPDIR}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- | " \
    "ark:ivector-subtract-global-mean ${EXPDIR}/xvectors_eval/mean.vec scp:${EXPDIR}/xvectors_eval/xvector.scp ark:- | "\
    "transform-vec ${EXPDIR}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- | " \
    "cat '$sre16_trials' | cut -d\  --fields=1,2 |" $EXPDIR/scores/lang_eval_scores || exit 1;
    # NOTE - removed ivector-subtract-global-mean exp/xvectors_sre16_major/mean.vec
    # The sre16_major is unlabelled in-domain data, which we currently don't have.

  utils/filter_scp.pl $sre16_trials_tgl ${EXPDIR}/scores/sre16_eval_scores > ${EXPDIR}/scores/sre16_eval_tgl_scores
  utils/filter_scp.pl $sre16_trials_yue ${EXPDIR}/scores/sre16_eval_scores > ${EXPDIR}/scores/sre16_eval_yue_scores
  pooled_eer=$(paste $sre16_trials ${EXPDIR}/scores/sre16_eval_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  tgl_eer=$(paste $sre16_trials_tgl ${EXPDIR}/scores/sre16_eval_tgl_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  yue_eer=$(paste $sre16_trials_yue ${EXPDIR}/scores/sre16_eval_yue_scores | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  echo "Using Out-of-Domain PLDA, EER: Pooled ${pooled_eer}%, Tagalog ${tgl_eer}%, Cantonese ${yue_eer}%"
  # EER: Pooled 11.73%, Tagalog 15.96%, Cantonese 7.52%
  # For reference, here's the ivector system from ../v1:
  # EER: Pooled 13.65%, Tagalog 17.73%, Cantonese 9.61%
fi

if [ $stage -eq 10 ]; then
  # Get results using the adapted PLDA model.
  $train_cmd $EXPDIR/scores/log/sre16_eval_scoring_adapt.log \
    ivector-plda-scoring --normalize-length=true \
    --num-utts=ark:$EXPDIR/xvectors_sre16_eval_enroll/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 ${EXPDIR}/xvectors_sre16_major/plda_adapt - |" \
    "ark:ivector-mean ark:data/sre16_eval_enroll/spk2utt scp:${EXPDIR}/xvectors_sre16_eval_enroll/xvector.scp ark:- | ivector-subtract-global-mean ${EXPDIR}/xvectors_sre16_major/mean.vec ark:- ark:- | transform-vec ${EXPDIR}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean ${EXPDIR}/xvectors_sre16_major/mean.vec scp:${EXPDIR}/xvectors_sre16_eval_test/xvector.scp ark:- | transform-vec ${EXPDIR}/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$sre16_trials' | cut -d\  --fields=1,2 |" ${EXPDIR}/scores/sre16_eval_scores_adapt || exit 1;

  utils/filter_scp.pl $sre16_trials_tgl ${EXPDIR}/scores/sre16_eval_scores_adapt > ${EXPDIR}/scores/sre16_eval_tgl_scores_adapt
  utils/filter_scp.pl $sre16_trials_yue ${EXPDIR}/scores/sre16_eval_scores_adapt > ${EXPDIR}/scores/sre16_eval_yue_scores_adapt
  pooled_eer=$(paste $sre16_trials ${EXPDIR}/scores/sre16_eval_scores_adapt | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  tgl_eer=$(paste $sre16_trials_tgl ${EXPDIR}/scores/sre16_eval_tgl_scores_adapt | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  yue_eer=$(paste $sre16_trials_yue ${EXPDIR}/scores/sre16_eval_yue_scores_adapt | awk '{print $6, $3}' | compute-eer - 2>/dev/null)
  echo "Using Adapted PLDA, EER: Pooled ${pooled_eer}%, Tagalog ${tgl_eer}%, Cantonese ${yue_eer}%"
  # EER: Pooled 8.57%, Tagalog 12.29%, Cantonese 4.89%
  # For reference, here's the ivector system from ../v1:
  # EER: Pooled 12.98%, Tagalog 17.8%, Cantonese 8.35%
  #
  # Using the official SRE16 scoring software, we obtain the following equalized results:
  #
  # -- Pooled --
  #  EER:          8.66
  #  min_Cprimary: 0.61
  #  act_Cprimary: 0.62
  #
  # -- Cantonese --
  # EER:           4.69
  # min_Cprimary:  0.42
  # act_Cprimary:  0.43
  #
  # -- Tagalog --
  # EER:          12.63
  # min_Cprimary:  0.76
  # act_Cprimary:  0.81
fi
