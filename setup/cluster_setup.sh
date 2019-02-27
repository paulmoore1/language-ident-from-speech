#!/usr/bin/env bash

./install_conda.sh

source activate lid

KALDI_DIR=$HOME

./install_kaldi.sh --root-dir=$KALDI_DIR
