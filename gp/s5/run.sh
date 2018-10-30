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

[ -f cmd.sh ] && source ./cmd.sh || echo "cmd.sh not found. Jobs may not execute properly."

# CHECKING FOR AND INSTALLING REQUIRED TOOLS:
#  This recipe requires shorten (3.6.1) and sox (14.3.2).
#  If they are not found, the local/gp_install.sh script will install them.
# Commented out as there's a minor bug where the sox is not recognised on the path
#local/gp_check_tools.sh $PWD path.sh || exit 1;

. path.sh || { echo "Cannot source path.sh"; exit 1; }

# Set the locations of the GlobalPhone corpus and language models
GP_CORPUS=/group/corpora/public/global_phone
#GP_LM=$PWD/language_models

#nnet_dir = exp/xvector_nnet_1a

stage=0

# Set the languages that will actually be processed
export GP_LANGUAGES="CR TU"

# The following data preparation step actually converts the audio files from
# shorten to WAV to take out the empty files and those with compression errors.

# Sections marked 'TEMP' have been removed just so that the same process is not run multiple times unnecessarily
local/gp_data_prep_new.sh --config-dir=$PWD/conf --corpus-dir=$GP_CORPUS --languages="$GP_LANGUAGES" || exit 1;
#local/gp_dict_prep.sh --config-dir $PWD/conf $GP_CORPUS $GP_LANGUAGES || exit 1;




:<<'END'
for L in $GP_LANGUAGES; do
  echo "Preparing language"
 utils/prepare_lang.sh --position-dependent-phones true \
   data/$L/local/dict "<unk>" data/$L/local/lang_tmp data/$L/lang \
   >& data/$L/prepare_lang.log || exit 1;
done


# Convert the different available language models to FSTs, and create separate
# decoding configurations for each.
for L in $GP_LANGUAGES; do
  echo "Formatting language"
   local/gp_format_lm.sh --filter-vocab-sri true $GP_LM $L &
done
wait
END

mfccdir = `pwd`/mfcc
vaddir = `pwd`/mfcc

:<<'END'
if [$stage -le 1]; then
# Now make MFCC features.
  for L in $GP_LANGUAGES; do
    echo "Making mfccs"
    #mfccdir=mfcc/$L
    for x in train dev eval; do
      (
        steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc.conf \
        --nj 40 --cmd "$train_cmd" data/$L/$x exp/$L/make_mfcc/$x $mfccdir;
          #steps/compute_cmvn_stats.sh data/$L/$x exp/$L/make_mfcc/$x $mfccdir;
        utils/fix_data_dir.sh data/$L/$x
        sid/compute_vad_decision.sh --nj 40 cmd "$train_cmd" \
        data/$L/$x exp/make_vad $vaddir
        utils/fix_data_dir.sh data/$L/$x
      ) &
    done
    echo "Combining data"
    utils/combine_data.sh --extra-files "utt2num_frames" data/FR
    utils/fix_data_dir.sh data/FR
  done
fi
wait;
END

#!!!!!!!!!!!!!!!!!!! Set to whatever will be the directory with all the combined data
data_dir=data/train
exp_dir=exp/train
#!!!!!!!!!!!!!!!!!!!


# In this section, the data is augmented with reverberation, noise, music and babble,
# and combined with the clean data. Note that the data directories are not correct.
# The combined list will be used to train the xvector DNN
:<<'END'
if [ $stage -le 2 ]; then
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' ${data_dir}/utt2num_frames > ${data_dir}/reco2dur

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
    ${data_dir} ${data_dir}_reverb
  cp ${data_dir}/vad.scp ${data_dir}_reverb
  utils/copy_data_dir.sh --utt-suffix "-reverb" ${data_dir}_reverb ${data_dir}_reverb.new
  rm -rf ${data_dir}_reverb
  mv ${data_dir}_reverb.new ${data_dir}_reverb

  # Prepare the MUSAN corpus, which consists of music, speech, and noise
  # suitable for augmentation.
  local/make_musan.sh /export/corpora/JHU/musan data

  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh data/musan_${name}
    mv data/musan_${name}/utt2dur data/musan_${name}/reco2dur
  done

  # Augment with musan_noise
  python steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "data/musan_noise" ${data_dir} ${data_dir}_noise
  # Augment with musan_music
  python steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "data/musan_music" ${data_dir} ${data_dir}_music
  # Augment with musan_speech
  python steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "data/musan_speech" ${data_dir} ${data_dir}_babble

  # Combine reverb, noise, music, and babble into one directory.
  utils/combine_data.sh ${data_dir}_aug ${data_dir}_reverb ${data_dir}_noise ${data_dir}_music ${data_dir}_babble

  # Take a random subset of the augmentations (128k is somewhat larger than twice
  # the size of the SWBD+SRE list)
  utils/subset_data_dir.sh ${data_dir}_aug 128000 ${data_dir}_aug_128k
  utils/fix_data_dir.sh ${data_dir}_aug_128k

  # Make MFCCs for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
    ${data_dir}_aug_128k exp/make_mfcc $mfccdir

  # Combine the clean and augmented SWBD+SRE list.  This is now roughly
  # double the size of the original clean list.
  utils/combine_data.sh ${data_dir}_combined ${data_dir}_aug_128k ${data_dir}

  # Filter out the clean + augmented portion of the SRE list.  This will be used to
  # train the PLDA model later in the script.
  utils/copy_data_dir.sh ${data_dir}_combined data/sre_combined

  #!!!!! Need to fix this part - sre will not exist, need alternative !!!!!!!
  utils/filter_scp.pl data/sre/spk2utt ${data_dir}_combined/spk2utt | utils/spk2utt_to_utt2spk.pl > data/sre_combined/utt2spk
  utils/fix_data_dir.sh data/sre_combined
fi


# Now we prepare the features to generate examples for xvector training.
if [ $stage -le 3 ]; then
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 40 --cmd "$train_cmd" \
    ${data_dir}_combined ${data_dir}_combined_no_sil ${exp_dir}_combined_no_sil
  utils/fix_data_dir.sh ${data_dir}_combined_no_sil

  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
  min_len=500
  mv ${data_dir}_combined_no_sil/utt2num_frames ${data_dir}_combined_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' ${data_dir}_combined_no_sil/utt2num_frames.bak > ${data_dir}_combined_no_sil/utt2num_frames
  utils/filter_scp.pl data/swbd_sre_combined_no_sil/utt2num_frames ${data_dir}_combined_no_sil/utt2spk > ${data_dir}_combined_no_sil/utt2spk.new
  mv ${data_dir}_combined_no_sil/utt2spk.new ${data_dir}_combined_no_sil/utt2spk
  utils/fix_data_dir.sh ${data_dir}_combined_no_sil

  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.

  #!!!!!!!!!!!!!!!
  # Remove section below for language id
  #!!!!!!!!!!!!!!!

  min_num_utts=8
  awk '{print $1, NF-1}' ${data_dir}_combined_no_sil/spk2utt > ${data_dir}_combined_no_sil/spk2num
  awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' ${data_dir}_combined_no_sil/spk2num | utils/filter_scp.pl - ${data_dir}_combined_no_sil/spk2utt > ${data_dir}_combined_no_sil/spk2utt.new
  mv ${data_dir}_combined_no_sil/spk2utt.new ${data_dir}_combined_no_sil/spk2utt
  utils/spk2utt_to_utt2spk.pl ${data_dir}_combined_no_sil/spk2utt > ${data_dir}_combined_no_sil/utt2spk

  utils/filter_scp.pl ${data_dir}_combined_no_sil/utt2spk ${data_dir}_combined_no_sil/utt2num_frames > ${data_dir}_combined_no_sil/utt2num_frames.new
  mv ${data_dir}_combined_no_sil/utt2num_frames.new ${data_dir}_combined_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh ${data_dir}_combined_no_sil
fi

local/nnet3/xvector/run_xvector.sh --stage $stage --train-stage -1 \
  --data ${data_dir}_combined_no_sil --nnet-dir $nnet_dir \
  --egs-dir $nnet_dir/egs


:<<'END' #rest of this is making language models which is unnecessary
for L in $GP_LANGUAGES; do
  mkdir -p exp/$L/mono;
  steps/train_mono.sh --nj 10 --cmd "$train_cmd" \
    data/$L/train data/$L/lang exp/$L/mono >& exp/$L/mono/train.log &
done
wait;


for L in $GP_LANGUAGES; do
  for lm_suffix in tgpr_sri; do
    (
      graph_dir=exp/$L/mono/graph_${lm_suffix}
      mkdir -p $graph_dir
      utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/mono \
	 $graph_dir

      steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/dev \
	 exp/$L/mono/decode_dev_${lm_suffix}
      steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/eval \
	 exp/$L/mono/decode_eval_${lm_suffix}
    ) &
  done
done

# Train tri1, which is first triphone pass
for L in $GP_LANGUAGES; do
  (
    mkdir -p exp/$L/mono_ali
    steps/align_si.sh --nj 10 --cmd "$train_cmd" \
	data/$L/train data/$L/lang exp/$L/mono exp/$L/mono_ali \
	>& exp/$L/mono_ali/align.log

    num_states=$(grep "^$L" conf/tri.conf | cut -f2)
    num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
    mkdir -p exp/$L/tri1
    steps/train_deltas.sh --cmd "$train_cmd" \
	--cluster-thresh 100 $num_states $num_gauss data/$L/train data/$L/lang \
	exp/$L/mono_ali exp/$L/tri1 >& exp/$L/tri1/train.log
  ) &
done
wait;

# Decode tri1
for L in $GP_LANGUAGES; do
  for lm_suffix in tgpr_sri; do
    (
      graph_dir=exp/$L/tri1/graph_${lm_suffix}
      mkdir -p $graph_dir
      utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/tri1 \
	$graph_dir

      steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/dev \
	exp/$L/tri1/decode_dev_${lm_suffix}
      steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/eval \
	exp/$L/tri1/decode_eval_${lm_suffix}
    ) &
  done
done


# Train tri2a, which is deltas + delta-deltas
for L in $GP_LANGUAGES; do
  (
    mkdir -p exp/$L/tri1_ali
    steps/align_si.sh --nj 10 --cmd "$train_cmd" \
	data/$L/train data/$L/lang exp/$L/tri1 exp/$L/tri1_ali \
	>& exp/$L/tri1_ali/tri1_ali.log

    num_states=$(grep "^$L" conf/tri.conf | cut -f2)
    num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
    mkdir -p exp/$L/tri2a
    steps/train_deltas.sh --cmd "$train_cmd" \
	--cluster-thresh 100 $num_states $num_gauss data/$L/train data/$L/lang \
	exp/$L/tri1_ali exp/$L/tri2a >& exp/$L/tri2a/train.log
  ) &
done
wait;

# Decode tri2a
for L in $GP_LANGUAGES; do
  for lm_suffix in tgpr_sri; do
    (
      graph_dir=exp/$L/tri2a/graph_${lm_suffix}
      mkdir -p $graph_dir
      utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/tri2a \
	$graph_dir

      steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/dev \
	exp/$L/tri2a/decode_dev_${lm_suffix}
      steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/eval \
	exp/$L/tri2a/decode_eval_${lm_suffix}
    ) &
  done
done

# Train tri2b, which is LDA+MLLT
for L in $GP_LANGUAGES; do
  (
    num_states=$(grep "^$L" conf/tri.conf | cut -f2)
    num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
    mkdir -p exp/$L/tri2b
    steps/train_lda_mllt.sh --cmd "$train_cmd" \
	--splice-opts "--left-context=3 --right-context=3" $num_states $num_gauss data/$L/train \
	data/$L/lang exp/$L/tri1_ali exp/$L/tri2b >& exp/$L/tri2b/tri2_ali.log
  ) &
done
wait;

# for L in $GP_LANGUAGES; do
#   mode=4
# # Doing this only for the LMs whose vocabs were limited using SRILM, since the
# # other approach didn't yield LMs for all languages.
#   steps/lmrescore.sh --mode $mode --cmd "$decode_cmd" \
#     data/$L/lang_test_tgpr_sri data/$L/lang_test_tg_sri data/$L/dev \
#     exp/$L/tri2a/decode_dev_tgpr_sri exp/$L/tri2a/decode_dev_tg_sri$mode
# done

# Decode tri2b
for L in $GP_LANGUAGES; do
  for lm_suffix in tgpr_sri; do
  (
    graph_dir=exp/$L/tri2b/graph_${lm_suffix}
    mkdir -p $graph_dir
    utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/tri2b \
	$graph_dir

    steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/dev \
	exp/$L/tri2b/decode_dev_${lm_suffix}
    steps/decode.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/eval \
	exp/$L/tri2b/decode_eval_${lm_suffix}
  ) &
  done
done
wait;

# Train tri3b, which is LDA+MLLT+SAT.
for L in $GP_LANGUAGES; do
  (
    mkdir -p exp/$L/tri2b_ali
    steps/align_si.sh --nj 10 --cmd "$train_cmd" \
	--use-graphs true data/$L/train data/$L/lang exp/$L/tri2b exp/$L/tri2b_ali \
	>& exp/$L/tri2b_ali/align.log

    num_states=$(grep "^$L" conf/tri.conf | cut -f2)
    num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
    mkdir -p exp/$L/tri3b
    steps/train_sat.sh --cmd "$train_cmd" \
	--cluster-thresh 100 $num_states $num_gauss data/$L/train data/$L/lang \
	exp/$L/tri2b_ali exp/$L/tri3b >& exp/$L/tri3b/train.log
  ) &
done
wait;

# Decode 3b
for L in $GP_LANGUAGES; do
  for lm_suffix in tgpr_sri; do
  (
    graph_dir=exp/$L/tri3b/graph_${lm_suffix}
    mkdir -p $graph_dir
    utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/tri3b \
	$graph_dir

    mkdir -p exp/$L/tri3b/decode_dev_${lm_suffix}
    steps/decode_fmllr.sh --nj 5 --cmd "$decode_cmd" \
	$graph_dir data/$L/dev exp/$L/tri3b/decode_dev_${lm_suffix}
    steps/decode_fmllr.sh --nj 5 --cmd "$decode_cmd" \
	$graph_dir data/$L/eval exp/$L/tri3b/decode_eval_${lm_suffix}
  ) &
done
done
wait;

## Train sgmm2b, which is SGMM on top of LDA+MLLT+SAT features.
for L in $GP_LANGUAGES; do
  (
    mkdir -p exp/$L/tri3b_ali
    steps/align_fmllr.sh --nj 10 --cmd "$train_cmd" \
	data/$L/train data/$L/lang exp/$L/tri3b exp/$L/tri3b_ali

    num_states=$(grep "^$L" conf/sgmm.conf | cut -f2)
    num_substates=$(grep "^$L" conf/sgmm.conf | cut -f3)
    mkdir -p exp/$L/ubm4a
    steps/train_ubm.sh --cmd "$train_cmd" \
	600 data/$L/train data/$L/lang exp/$L/tri3b_ali exp/$L/ubm4a

    mkdir -p exp/$L/sgmm2_4a
    steps/train_sgmm2.sh --cmd "$train_cmd" \
	$num_states $num_substates data/$L/train data/$L/lang exp/$L/tri3b_ali \
	exp/$L/ubm4a/final.ubm exp/$L/sgmm2_4a
  ) &
done
wait;

## Decode sgmm2_4a
for L in $GP_LANGUAGES; do
 for lm_suffix in tgpr_sri; do
  (
    graph_dir=exp/$L/sgmm2_4a/graph_${lm_suffix}
    mkdir -p $graph_dir
    utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/sgmm2_4a \
	$graph_dir

    steps/decode_sgmm2.sh --use-fmllr true --nj 5 --cmd "$decode_cmd" \
	--transform-dir exp/$L/tri3b/decode_dev_${lm_suffix}  $graph_dir data/$L/dev \
	exp/$L/sgmm2_4a/decode_dev_${lm_suffix}
    steps/decode_sgmm2.sh --use-fmllr true --nj 5 --cmd "$decode_cmd" \
	--transform-dir exp/$L/tri3b/decode_eval_${lm_suffix}  $graph_dir data/$L/eval \
	exp/$L/sgmm2_4a/decode_eval_${lm_suffix}
  )
 done
done
wait;


# Now we'll align the SGMM system to prepare for discriminative training MMI
for L in $GP_LANGUAGES; do
 for lm_suffix in tgpr_sri; do
  (
    mkdir -p exp/$L/sgmm2_4a_ali
    steps/align_sgmm2.sh --nj 10 --cmd "$train_cmd" \
	--transform-dir exp/$L/tri3b_ali --use-graphs true --use-gselect true data/$L/train \
	data/$L/lang exp/$L/sgmm2_4a exp/$L/sgmm2_4a_ali

    mkdir -p exp/$L/sgmm2_4a_denlats
    steps/make_denlats_sgmm2.sh --nj 10 --sub-split 10 --cmd "$decode_cmd" \
	--transform-dir exp/$L/tri3b_ali data/$L/train data/$L/lang \
	exp/$L/sgmm2_4a_ali exp/$L/sgmm2_4a_denlats
    mkdir -p exp/$L/sgmm2_4a_mmi_b0.1
    steps/train_mmi_sgmm2.sh --cmd "$decode_cmd" \
	--transform-dir exp/$L/tri3b_ali --boost 0.1 data/$L/train data/$L/lang \
	exp/$L/sgmm2_4a_ali exp/$L/sgmm2_4a_denlats exp/$L/sgmm2_4a_mmi_b0.1
  ) &
 done
done
wait;

# decode sgmm2_4a-mmi_b0.1
for L in $GP_LANGUAGES; do
 for lm_suffix in tgpr_sri; do
  (
   graph_dir=exp/$L/sgmm2_4a/graph_${lm_suffix}
    for iter in 1 2 3 4; do
     for test in dev eval; do
      steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" \
	--iter $iter --transform-dir exp/$L/tri3b/decode_${test}_${lm_suffix} data/$L/lang_test_${lm_suffix} \
	data/$L/${test} exp/$L/sgmm2_4a/decode_${test}_${lm_suffix} \
	exp/$L/sgmm2_4a_mmi_b0.1/decode_${test}_${lm_suffix}_it$iter
     done
    done
  ) &
 done
done
wait;


# SGMMs starting from non-SAT triphone system, both with and without
# speaker vectors.
for L in $GP_LANGUAGES; do
  (
    mkdir -p exp/$L/ubm2a
    steps/train_ubm.sh --cmd "$train_cmd" \
	400 data/$L/train data/$L/lang exp/$L/tri1_ali exp/$L/ubm2a \
	>& exp/$L/ubm2a/train.log

    num_states=$(grep "^$L" conf/sgmm.conf | cut -f2)
    num_substates=$(grep "^$L" conf/sgmm.conf | cut -f3)
    mkdir -p exp/$L/sgmm2a
    steps/train_sgmm2.sh --cmd "$train_cmd" --cluster-thresh 100 --spk-dim 0 \
      $num_states $num_substates data/$L/train data/$L/lang exp/$L/tri1_ali \
      exp/$L/ubm2a/final.ubm exp/$L/sgmm2a >& exp/$L/sgmm2a/train.log

    mkdir -p exp/$L/sgmm2b
    steps/train_sgmm2.sh --cmd "$train_cmd" --cluster-thresh 100 \
      $num_states $num_gauss data/$L/train data/$L/lang exp/$L/tri1_ali \
      exp/$L/ubm2a/final.ubm exp/$L/sgmm2b >& exp/$L/sgmm2b/train.log
  ) &
done
wait

for L in $GP_LANGUAGES; do
  # Need separate decoding graphs for models with and without speaker vectors,
  # since the trees may be different.
  for sgmm in sgmm2a sgmm2b; do
    for lm_suffix in tgpr_sri; do
      (
	graph_dir=exp/$L/$sgmm/graph_${lm_suffix}
	mkdir -p $graph_dir
	$highmem_cmd $graph_dir/mkgraph.log \
	  utils/mkgraph.sh data/$L/lang_test_${lm_suffix} exp/$L/$sgmm $graph_dir

	steps/decode_sgmm2.sh --nj 5 --cmd "$decode_cmd" $graph_dir data/$L/dev \
	  exp/$L/$sgmm/decode_dev_${lm_suffix}
      ) &
    done  # loop over LMs
  done    # loop over model with and without speaker vecs
done      # loop over languages
END
