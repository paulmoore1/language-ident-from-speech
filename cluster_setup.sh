#!/usr/bin/env bash

./install_conda.sh

source activate lid

KALDI_DIR=..

./install_kaldi.sh --root-dir=$KALDI_DIR
