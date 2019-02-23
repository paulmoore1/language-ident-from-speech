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
\t       --home-dir=DIRECTORY\tMain directory where recipe is stored
\t       --exp-config=FILE\tConfig file with all kinds of options,\n
\t       \t\t\tsee conf/exp_default.conf for an example.\n
\t       \t\t\tNOTE: Where arguments are passed on the command line,\n
\t       \t\t\tthe values overwrite those found in the config file.\n\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Default option values
exp_name="baseline"
stage=-1
run_all=false
exp_config=NONE
num_epochs=3
feature_type=mfcc
skip_nnet_training=false

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --home-dir=*)
  home_dir=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --exp-config=*)
  exp_config=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
echo -e $usage

# Run from the home directory
cd $home_dir
conf_dir=$home_dir/conf
exp_conf_dir=$conf_dir/exp_configs

if [ ! "$exp_config" == "NONE" ] && [ ! -f $exp_conf_dir/$exp_config ]; then
  echo "Configuration file '${exp_config}' not found for this experiment."
  exit 1;
fi

# Source some variables from the experiment-specific config file
source $exp_conf_dir/$exp_config || echo "Problems sourcing the experiment config file: $exp_conf_dir/$exp_config"

# Use arguments passed to this script on the command line
# to overwrite the values sourced from the experiment-specific config.
command_line_options="run_all stage exp_name"
for cl_opt in $command_line_options; do
  var="${cl_opt}_cl"
  if [[ -v $var ]]; then
    echo "Overwriting the experiment config value of ${cl_opt}=${!cl_opt}"\
      "using the value '${!var}' passed as a command-line argument."
    declare $cl_opt="${!var}"
  fi
done

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
./local/gp_check_tools.sh $home_dir path.sh || exit 1;

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

home_prefix=$DATADIR/$exp_name
train_data=$home_prefix/train
enroll_data=$home_prefix/enroll
eval_data=$home_prefix/eval
test_data=$home_prefix/test
tamil_data=$home_prefix/tamil
log_dir=$home_prefix/log
mfcc_dir=$home_prefix/mfcc
mfcc_sdc_dir=$home_prefix/mfcc_sdc
sdc_dir=$home_prefix/mfcc_sdc
mfcc_deltas_dir=$home_prefix/mfcc_deltas
vaddir=$home_prefix/vad
feat_dir=$home_prefix/x_vector_features
nnet_train_data=$home_prefix/nnet_train_data
nnet_dir=$home_prefix/nnet
exp_dir=$home_prefix/exp

# If using existing preprocessed data for computing x-vectors
if [ ! -z "$use_dnn_egs_from" ]; then
  home_prefix=$DATADIR/$use_dnn_egs_from
  echo "Using preprocessed data	from: $home_prefix"

  if [ ! -d $home_prefix ]; then
    echo "ERROR: directory containging preprocessed data not found: '$home_prefix'"
    exit 1
  fi

  train_data=$home_prefix/train
  enroll_data=$home_prefix/enroll
  eval_data=$home_prefix/eval
  test_data=$home_prefix/test
  nnet_train_data=$home_prefix/nnet_train_data
  preprocessed_data_dir=$DATADIR/$use_dnn_egs_from
fi

# If the model requested for use is an actual directory with a model in it
if [ -d $DATADIR/$use_model_from/nnet ]; then
  skip_nnet_training=true
  nnet_dir=$DATADIR/$use_model_from/nnet
  echo "Model found!"
else
  echo "Model not found in $DATADIR/$use_model_from/nnet"
fi

DATADIR="${DATADIR}/$exp_name"
mkdir -p $DATADIR
mkdir -p $DATADIR/log
echo "The experiment directory is: $DATADIR"

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
  --stage 0 \
  $nnet_dir \
  # Change this to the directory with data.
  $enroll_data/split \
  $exp_dir/xvectors_enroll &

  wait;

mkdir -p $exp_dir/results

# Classifying test set samples on existing model
./local/test_logistic_regression.sh \
  --prior-scale 0.70 \
  --conf conf/logistic-regression.conf \
  # Change this to the directory with xvectors
  --test-dir $exp_dir/xvectors_eval \
  --model-dir $exp_dir/classifier \
  --classification-file $exp_dir/results/classification \
  --train-utt2lang $enroll_data/split/utt2lang \
  --test-utt2lang $eval_data/split/utt2lang \
  --languages conf/test_languages.list \
  > $exp_dir/classifier/logistic-regression.log

# TODO display results
