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

if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
	echo "Seems like your conda environment is not activated. Use: source activate ENVNAME."
	exit
else
	echo "Conda environment '$CONDA_DEFAULT_ENV' active."
fi

[ -f conf/user_specific_config.sh ] && source ./conf/general_config.sh \
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

<<<<<<< HEAD
#!!!TODO!!! - change before running each time atm
DATADIR=/afs/inf.ed.ac.uk/user/s15/s1531206/gp-data
=======
>>>>>>> 7552d160c2843565fc8c4d6365736a4d532a6d78
TRAINDIR=$DATADIR/train
mfccdir=$DATADIR/mfcc
vaddir=$DATADIR/mfcc
nnetdir=exp/xvector_nnet_1a

export GP_LANGUAGES="CR TU" # Set the languages that will actually be processed
stage=0
:<<'TEMP'
# The following data preparation step actually converts the audio files from
# shorten to WAV to take out the empty files and those with compression errors.
if [ $stage -le 0 ]; then
	local/gp_data_prep.sh \
		--config-dir=$PWD/conf \
		--corpus-dir=$GP_CORPUS \
		--languages="$GP_LANGUAGES" \
		--data-dir=$DATADIR \
		|| exit 1;
	#local/gp_dict_prep.sh --config-dir $PWD/conf $GP_CORPUS $GP_LANGUAGES || exit 1;
fi
TEMP


# Now make MFCC features.
<<<<<<< HEAD
#:<<'TEMP'
=======
:<<'END'
for x in train eval; do
(
  steps/make_mfcc.sh \
  	--nj $MAXNUMJOBS \
  	--cmd "$train_cmd" \
  	$DATADIR/$x \
    $DATADIR/logs/make_mfcc/$x \
    $mfccdir;

  steps/compute_cmvn_stats.sh $DATADIR/$x $DATADIR/logs/make_mfcc/$x $mfccdir;
) &
done
wait;
END
:<<'TEMP'
>>>>>>> 7552d160c2843565fc8c4d6365736a4d532a6d78
if [ $stage -le 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset
  #TODO is this doing anything important?
  #if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $mfccdir/storage ]; then
  #  utils/create_split_dir.pl \
  #    /export/b{14,15,16,17}/$USER/kaldi-data/egs/sre16/v2/xvector-$(date +'%m_%d_%H_%M')/mfccs/storage $mfccdir/storage
  #fi
  for name in train eval; do
    steps/make_mfcc.sh \
      --write-utt2num-frames true \
      --mfcc-config conf/mfcc.conf \
<<<<<<< HEAD
      --nj 6 \
=======
      --nj $MAXNUMJOBS \
>>>>>>> 7552d160c2843565fc8c4d6365736a4d532a6d78
      --cmd "$train_cmd" \
      $DATADIR/${name} \
      exp/make_mfcc \
      $mfccdir

    utils/fix_data_dir.sh $DATADIR/${name}

    sid/compute_vad_decision.sh \
<<<<<<< HEAD
      --nj 6 \
=======
      --nj $MAXNUMJOBS \
>>>>>>> 7552d160c2843565fc8c4d6365736a4d532a6d78
      --cmd "$train_cmd" \
      $DATADIR/${name} \
      exp/make_vad \
      $vaddir

    utils/fix_data_dir.sh $DATADIR/${name}
  done
	#utils/combine_data.sh --extra-files 'utt2num_frames' $DATADIR/
  utils/fix_data_dir.sh $TRAINDIR
fi
exit
#TEMP

:<<'TEMP'
#In order to fix this, we need the MUSAN corpus - currently skipping augmentation
# In this section, we augment the training data with reverberation,
# noise, music, and babble, and combined it with the clean data.
# The combined list will be used to train the xvector DNN.  The SRE
# subset will be used to train the PLDA model.
if [ $stage -le 2 ]; then
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
TEMP

# Now we prepare the features to generate examples for xvector training.
if [ $stage -le 3 ]; then
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
<<<<<<< HEAD
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 6 --cmd "$train_cmd" \
=======
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
>>>>>>> 7552d160c2843565fc8c4d6365736a4d532a6d78
    $TRAINDIR $TRAINDIR/combined_no_sil exp/train_combined_no_sil
		# !!!TODO change to $TRAINDIR/combined when data augmentation works
  utils/fix_data_dir.sh $TRAINDIR/combined_no_sil
	exit
  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
	echo "Removing silence frames..."
  min_len=500
  mv $TRAINDIR/combined_no_sil/utt2num_frames $TRAINDIR/combined_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' $TRAINDIR/combined_no_sil/utt2num_frames.bak > $TRAINDIR/combined_no_sil/utt2num_frames
  utils/filter_scp.pl $TRAINDIR/combined_no_sil/utt2num_frames $TRAINDIR/combined_no_sil/utt2spk > $TRAINDIR/combined_no_sil/utt2spk.new
  mv $TRAINDIR/combined_no_sil/utt2spk.new $TRAINDIR/combined_no_sil/utt2spk
  utils/fix_data_dir.sh $TRAINDIR/combined_no_sil
	echo "Done"
  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.
	echo "Removing speakers with < 8 utterances..."
  min_num_utts=8
  awk '{print $1, NF-1}' $TRAINDIR/combined_no_sil/spk2utt > $TRAINDIR/combined_no_sil/spk2num
  awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' $TRAINDIR/combined_no_sil/spk2num | utils/filter_scp.pl - $TRAINDIR/combined_no_sil/spk2utt > $TRAINDIR/combined_no_sil/spk2utt.new
  mv $TRAINDIR/combined_no_sil/spk2utt.new $TRAINDIR/combined_no_sil/spk2utt
  utils/spk2utt_to_utt2spk.pl $TRAINDIR/combined_no_sil/spk2utt > $TRAINDIR/combined_no_sil/utt2spk
	echo "Done"
  utils/filter_scp.pl $TRAINDIR/combined_no_sil/utt2spk $TRAINDIR/combined_no_sil/utt2num_frames > $TRAINDIR/combined_no_sil/utt2num_frames.new
  mv $TRAINDIR/combined_no_sil/utt2num_frames.new $TRAINDIR/combined_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh $TRAINDIR/combined_no_sil
fi
exit
