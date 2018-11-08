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

echo \
$'+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
       This shell script runs the GlobalPhone+X-vectors recipe.
       Use like this: ./run.sh stagenumber
       or don\'t provide stage number to run the whole recipe.
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'

if [ $# -lt 1 ]; then
	echo "No stage specified; assuming stage 0 and running the recipe from the beginning."
  stage=0
else
	echo "Continuing from stage $1"
	stage=$1
fi

# if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
# 	echo "Seems like your conda environment is not activated. Use: source activate ENVNAME."
# 	exit
# else
# 	echo "Conda environment '$CONDA_DEFAULT_ENV' active."
# fi

[ -f conf/general_config.sh ] && source ./conf/general_config.sh \
	|| echo "conf/general_config.sh not found or contains errors!"
MAXNUMJOBS=2

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
GP_LM=../../../gp-lang-models/

TRAINDIR=$DATADIR/train
mfccdir=$DATADIR/mfcc
vaddir=$DATADIR/mfcc
nnet_dir=$DATADIR/exp/xvector_nnet_1a

export GP_LANGUAGES="RU" # Set the languages that will actually be processed

# The following data preparation step actually converts the audio files from
# shorten to WAV to take out the empty files and those with compression errors.
if [ $stage -le 0 ]; then
  echo "#### STAGE 0: Data preparation. ####"
  # :<<'TEMP'
  local/gp_data_prep_GP.sh \
		--config-dir=$PWD/conf \
		--corpus-dir=$GP_CORPUS \
		--languages="$GP_LANGUAGES" \
		--data-dir=$DATADIR \
		|| exit 1;

  echo "Dictionary preparation..."
	local/gp_dict_prep.sh \
    --config-dir $PWD/conf \
    $GP_CORPUS \
    $DATADIR \
    $GP_LANGUAGES \
    || exit 1;
  echo "Language preparation..."
  for L in $GP_LANGUAGES; do
    utils/prepare_lang.sh --position-dependent-phones true \
      $DATADIR/$L/local/dict "<unk>" $DATADIR/$L/local/lang_tmp $DATADIR/$L/lang \
     >& $DATADIR/$L/prepare_lang.log || exit 1;
  done
# TEMP
  # Convert the different available language models to FSTs, 
  # and create separate decoding configurations for each.
  echo "Formatting LMs..."
  for L in $GP_LANGUAGES; do
    local/gp_format_lm.sh --filter-vocab-sri true $DATADIR $GP_LM $L &
  done
  wait
fi

exit

# Now make MFCC features.
if [ $stage -le 1 ]; then
  echo "#### STAGE 1: MFCCs. ####"
  for L in $GP_LANGUAGES; do
    mfccdir=mfcc/$L
    for x in train dev eval; do
      (
        steps/make_mfcc.sh --nj $MAXNUMJOBS --cmd "$train_cmd" $DATADIR/$L/$x \
          exp/$L/make_mfcc/$x $mfccdir;
        steps/compute_cmvn_stats.sh $DATADIR/$L/$x exp/$L/make_mfcc/$x $mfccdir;
      ) &
    done
  done
  wait;
fi

if [ $stage -le 2 ]; then
  echo "#### STAGE 2: Training models. ####"
  :<<'TEMP'

  # TO-DO: Revert num_iters to 40 in steps/train_mono.sh
  echo "Training mono..."
  for L in $GP_LANGUAGES; do
    mkdir -p exp/$L/mono;
    steps/train_mono.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
      $DATADIR/$L/train $DATADIR/$L/lang exp/$L/mono >& exp/$L/mono/train.log &
  done
  wait;

  echo "Making graph and decoding..."
  for L in $GP_LANGUAGES; do
    for lm_suffix in "tgpr_sri"; do
      (
        graph_dir=exp/$L/mono/graph_${lm_suffix}
        mkdir -p $graph_dir
        echo "Making graph..."
        utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/mono \
           $graph_dir

        # egs/wsj/s5/utils/format_lm_sri.sh:85:           --read-symbol-table=$out_dir/words.txt - $out_dir/G.fst || exit 1
        # egs/wsj/s5/local/wsj_format_data.sh:53:             --read-symbol-table=$test/words.txt - $test/G.fst
        # egs/wsj/s5/utils/validate_lang.pl:913:  # Check that G.fst is ilabel sorted and nonempty.
        # egs/wsj/s5/utils/lang/make_phone_bigram_lang.sh:104:    fstarcsort --sort_type=ilabel > $lang_out/G.fst
        # egs/wsj/s5/utils/format_lm.sh:56:             --read-symbol-table=$out_dir/words.txt - $out_dir/G.fst

        exit
        echo "Decoding dev..."
        steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/dev \
           exp/$L/mono/decode_dev_${lm_suffix}
        
        echo "Decoding eval..."
        steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/eval \
           exp/$L/mono/decode_eval_${lm_suffix}
      )
    done
  done

  # Train tri1, which is first triphone pass
  for L in $GP_LANGUAGES; do
    (
      mkdir -p exp/$L/mono_ali
      steps/align_si.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
          $DATADIR/$L/train $DATADIR/$L/lang exp/$L/mono exp/$L/mono_ali \
          >& exp/$L/mono_ali/align.log

      num_states=$(grep "^$L" conf/tri.conf | cut -f2)
      num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
      mkdir -p exp/$L/tri1
      steps/train_deltas.sh --cmd "$train_cmd" \
          --cluster-thresh 100 $num_states $num_gauss $DATADIR/$L/train $DATADIR/$L/lang \
          exp/$L/mono_ali exp/$L/tri1 >& exp/$L/tri1/train.log
    )
  done
  wait;

  # Decode tri1
  for L in $GP_LANGUAGES; do
    for lm_suffix in tgpr_sri; do
      (
        graph_dir=exp/$L/tri1/graph_${lm_suffix}
        mkdir -p $graph_dir
        utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/tri1 \
          $graph_dir


        # These two decode.sh calls fail. For a possible fix check out:
        # https://groups.google.com/forum/#!msg/kaldi-help/0SuCkeHyUmU/qIW-INChAAAJ
        # The errors (from exp/RU/tri1/decode_dev_tgpr_sri/log/decode.*.log):
        # ERROR: FstImpl::ReadHeader: FST not of type vector: <unspecified>
        # ERROR (gmm-latgen-faster[5.1.0-41fd]:ReadFstKaldi():kaldi-fst-io.cc:40) Could not read fst from exp/RU/tri1/graph_tgpr_sri/HCLG.fst
        steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/dev \
          exp/$L/tri1/decode_dev_${lm_suffix}
        steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/eval \
          exp/$L/tri1/decode_eval_${lm_suffix}
      )
    done
  done

  # Train tri2a, which is deltas + delta-deltas
  for L in $GP_LANGUAGES; do
    (
      mkdir -p exp/$L/tri1_ali
      steps/align_si.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
          $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri1 exp/$L/tri1_ali \
          >& exp/$L/tri1_ali/tri1_ali.log

      num_states=$(grep "^$L" conf/tri.conf | cut -f2)
      num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
      mkdir -p exp/$L/tri2a
      steps/train_deltas.sh --cmd "$train_cmd" \
          --cluster-thresh 100 $num_states $num_gauss $DATADIR/$L/train $DATADIR/$L/lang \
          exp/$L/tri1_ali exp/$L/tri2a >& exp/$L/tri2a/train.log
    )
  done
  wait;

  # Decode tri2a
  for L in $GP_LANGUAGES; do
    for lm_suffix in tgpr_sri; do
      (
        graph_dir=exp/$L/tri2a/graph_${lm_suffix}
        mkdir -p $graph_dir
        utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/tri2a \
          $graph_dir

        steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/dev \
          exp/$L/tri2a/decode_dev_${lm_suffix}
        steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/eval \
          exp/$L/tri2a/decode_eval_${lm_suffix}
      )
    done
  done

TEMP
  exit

  # Train tri2b, which is LDA+MLLT
  for L in $GP_LANGUAGES; do
    (
      num_states=$(grep "^$L" conf/tri.conf | cut -f2)
      num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
      mkdir -p exp/$L/tri2b
      steps/train_lda_mllt.sh --cmd "$train_cmd" \
          --splice-opts "--left-context=3 --right-context=3" $num_states $num_gauss $DATADIR/$L/train \
          $DATADIR/$L/lang exp/$L/tri1_ali exp/$L/tri2b >& exp/$L/tri2b/tri2_ali.log
    ) &
  done
  wait;

  # for L in $GP_LANGUAGES; do
  #   mode=4
  # # Doing this only for the LMs whose vocabs were limited using SRILM, since the
  # # other approach didn't yield LMs for all languages.
  #   steps/lmrescore.sh --mode $mode --cmd "$decode_cmd" \
  #     $DATADIR/$L/lang_test_tgpr_sri $DATADIR/$L/lang_test_tg_sri $DATADIR/$L/dev \
  #     exp/$L/tri2a/decode_dev_tgpr_sri exp/$L/tri2a/decode_dev_tg_sri$mode
  # done

  # Decode tri2b
  for L in $GP_LANGUAGES; do
    for lm_suffix in tgpr_sri; do
    (
      graph_dir=exp/$L/tri2b/graph_${lm_suffix}
      mkdir -p $graph_dir
      utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/tri2b \
          $graph_dir

      steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/dev \
          exp/$L/tri2b/decode_dev_${lm_suffix}
      steps/decode.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/eval \
          exp/$L/tri2b/decode_eval_${lm_suffix}
    ) &
    done
  done
  wait;

  # Train tri3b, which is LDA+MLLT+SAT.
  for L in $GP_LANGUAGES; do
    (
      mkdir -p exp/$L/tri2b_ali
      steps/align_si.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
          --use-graphs true $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri2b exp/$L/tri2b_ali \
          >& exp/$L/tri2b_ali/align.log

      num_states=$(grep "^$L" conf/tri.conf | cut -f2)
      num_gauss=$(grep "^$L" conf/tri.conf | cut -f3)
      mkdir -p exp/$L/tri3b
      steps/train_sat.sh --cmd "$train_cmd" \
          --cluster-thresh 100 $num_states $num_gauss $DATADIR/$L/train $DATADIR/$L/lang \
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
      utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/tri3b \
          $graph_dir

      mkdir -p exp/$L/tri3b/decode_dev_${lm_suffix}
      steps/decode_fmllr.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" \
          $graph_dir $DATADIR/$L/dev exp/$L/tri3b/decode_dev_${lm_suffix}
      steps/decode_fmllr.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" \
          $graph_dir $DATADIR/$L/eval exp/$L/tri3b/decode_eval_${lm_suffix}
    ) &
  done
  done
  wait;

  ## Train sgmm2b, which is SGMM on top of LDA+MLLT+SAT features.
  for L in $GP_LANGUAGES; do
    (
      mkdir -p exp/$L/tri3b_ali
      steps/align_fmllr.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
          $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri3b exp/$L/tri3b_ali

      num_states=$(grep "^$L" conf/sgmm.conf | cut -f2)
      num_substates=$(grep "^$L" conf/sgmm.conf | cut -f3)
      mkdir -p exp/$L/ubm4a
      steps/train_ubm.sh --cmd "$train_cmd" \
          600 $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri3b_ali exp/$L/ubm4a

      mkdir -p exp/$L/sgmm2_4a
      steps/train_sgmm2.sh --cmd "$train_cmd" \
          $num_states $num_substates $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri3b_ali \
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
      utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/sgmm2_4a \
          $graph_dir

      steps/decode_sgmm2.sh --use-fmllr true --nj $MAXNUMJOBS --cmd "$decode_cmd" \
          --transform-dir exp/$L/tri3b/decode_dev_${lm_suffix}  $graph_dir $DATADIR/$L/dev \
          exp/$L/sgmm2_4a/decode_dev_${lm_suffix}
      steps/decode_sgmm2.sh --use-fmllr true --nj $MAXNUMJOBS --cmd "$decode_cmd" \
          --transform-dir exp/$L/tri3b/decode_eval_${lm_suffix}  $graph_dir $DATADIR/$L/eval \
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
      steps/align_sgmm2.sh --nj $MAXNUMJOBS --cmd "$train_cmd" \
          --transform-dir exp/$L/tri3b_ali --use-graphs true --use-gselect true $DATADIR/$L/train \
          $DATADIR/$L/lang exp/$L/sgmm2_4a exp/$L/sgmm2_4a_ali

      mkdir -p exp/$L/sgmm2_4a_denlats
      steps/make_denlats_sgmm2.sh --nj $MAXNUMJOBS --sub-split 10 --cmd "$decode_cmd" \
          --transform-dir exp/$L/tri3b_ali $DATADIR/$L/train $DATADIR/$L/lang \
          exp/$L/sgmm2_4a_ali exp/$L/sgmm2_4a_denlats
      mkdir -p exp/$L/sgmm2_4a_mmi_b0.1
      steps/train_mmi_sgmm2.sh --cmd "$decode_cmd" \
          --transform-dir exp/$L/tri3b_ali --boost 0.1 $DATADIR/$L/train $DATADIR/$L/lang \
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
          --iter $iter --transform-dir exp/$L/tri3b/decode_${test}_${lm_suffix} $DATADIR/$L/lang_test_${lm_suffix} \
          $DATADIR/$L/${test} exp/$L/sgmm2_4a/decode_${test}_${lm_suffix} \
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
          400 $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri1_ali exp/$L/ubm2a \
          >& exp/$L/ubm2a/train.log

      num_states=$(grep "^$L" conf/sgmm.conf | cut -f2)
      num_substates=$(grep "^$L" conf/sgmm.conf | cut -f3)
      mkdir -p exp/$L/sgmm2a
      steps/train_sgmm2.sh --cmd "$train_cmd" --cluster-thresh 100 --spk-dim 0 \
        $num_states $num_substates $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri1_ali \
        exp/$L/ubm2a/final.ubm exp/$L/sgmm2a >& exp/$L/sgmm2a/train.log

      mkdir -p exp/$L/sgmm2b
      steps/train_sgmm2.sh --cmd "$train_cmd" --cluster-thresh 100 \
        $num_states $num_gauss $DATADIR/$L/train $DATADIR/$L/lang exp/$L/tri1_ali \
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
            utils/mkgraph.sh $DATADIR/$L/lang_test_${lm_suffix} exp/$L/$sgmm $graph_dir

          steps/decode_sgmm2.sh --nj $MAXNUMJOBS --cmd "$decode_cmd" $graph_dir $DATADIR/$L/dev \
            exp/$L/$sgmm/decode_dev_${lm_suffix}
        ) &
      done  # loop over LMs
    done    # loop over model with and without speaker vecs
  done      # loop over languages
fi
