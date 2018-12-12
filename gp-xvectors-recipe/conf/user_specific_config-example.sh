#!/bin/bash

# Directory where preprocessed data will be stored. Usually grows to a few GBs
# as the preprocessing and feature extraction run.
DATADIR=~/gp-data


KALDI_ROOT=~/kaldi

[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh

KALDISRC=$KALDI_ROOT/src
KALDIBIN=$KALDISRC/bin:$KALDISRC/featbin:$KALDISRC/fgmmbin:$KALDISRC/fstbin
KALDIBIN=$KALDIBIN:$KALDISRC/gmmbin:$KALDISRC/latbin:$KALDISRC/nnetbin:$KALDISRC/nnet3bin:$KALDISRC/nnet2bin
KALDIBIN=$KALDIBIN:$KALDISRC/sgmm2bin:$KALDISRC/lmbin:$KALDISRC/ivectorbin
FSTBIN=$KALDI_ROOT/tools/openfst/bin
LMBIN=$KALDI_ROOT/tools/irstlm/bin

export PATH=$PATH:$KALDIBIN:$FSTBIN:$LMBIN
