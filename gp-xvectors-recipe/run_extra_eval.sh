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
\t       This shell script evaluates the performance of a classifier on\n
\t       utterances of lengths 3 and 10s
\t       Use like this: $0 <options>\n
\t       --home-dir=DIRECTORY\tMain directory where recipe is stored
\t       --config=FILE\tConfig file with all kinds of options,\n
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
config=NONE
num_epochs=3
feature_type=mfcc
skip_nnet_training=true
use_model_from=NONE
use_data_augmentation=false
use_preprocessed=false
aug_expt=
GP_CORPUS=

while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config=*)
  config=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
echo -e $usage

#--home-dir=*)
#home_dir=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;

# Run from the home directory
home_dir=~/language-ident-from-speech/gp-xvectors-recipe
cd $home_dir
conf_dir=$home_dir/conf
exp_conf_dir=$conf_dir/eval_configs

config="${config}.conf"
if [ "$config" == "NONE" ] || [ ! -f $exp_conf_dir/${config} ]; then
  echo "Configuration file '${config}' not found for this experiment in $exp_conf_dir."
  exit 1;
fi

# Source some variables from the experiment-specific config file
source $exp_conf_dir/$config || echo "Problems sourcing the experiment config file: $exp_conf_dir/$config"; exit 1

echo "Running experiment: '$exp_name'"

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
if [[ $(whichMachine) != "paul" ]]; then
  ./local/gp_check_tools.sh $home_dir path.sh || exit 1;
fi

. ./path.sh || { echo "Cannot source path.sh"; exit 1; }

root_data_dir=$DATADIR

# Check any requested model exists
model_dir=$root_data_dir/$use_model_from/exp/classifier
if [ ! -d $model_dir ]; then
  echo "Error: model not found in ${model_dir}"
fi

for evaluation_length in (3 10); do
  DATADIR="${root_data_dir}/$exp_name/extra_eval/length_${evaluation_length}s"
  mkdir -p $DATADIR
  exp_dir=$DATADIR
  echo "The experiment directory is: $DATADIR"

  echo "Setting up preprocessed data"
  processed_dir=$root_data_dir/all_preprocessed
  ./local/prep_preprocessed.sh \
    --config-dir=$conf_dir \
    --processed-dir=$processed_dir \
    --data-augmentation=$use_data_augmentation \
    --train-languages="SKIP" \
    --enroll-languages="SKIP" \
    --eval-languages="$GP_EVAL_LANGUAGES" \
    --test-languages="$GP_TEST_LANGUAGES" \
    --data-dir=$DATADIR \
    --train-config-file-path=${conf_dir}/lre_configs/${lre_train_config} \
    --enroll-config-file-path=${conf_dir}/lre_configs/${lre_enroll_config} \
    --enrollment-length=$enrollment_length \
    --evaluation-length=$evaluation_length \
    --test-length=$test_length
  echo "Finished running"

  eval_data=$DATADIR/eval

  remove_nonspeech=false
  exit 0
  # X-vectors for end-to-end evaluation
  ./local/extract_xvectors.sh \
    --cmd "$extract_cmd --mem 6G" \
    --use-gpu $use_gpu \
    --nj 1 \
    --stage 0 \
    --remove-nonspeech "$remove_nonspeech" \
    $nnet_dir \
    $eval_data \
    $exp_dir/xvectors_eval &

  # X-vectors for testing (final evaluation)
  #./local/extract_xvectors.sh \
  #  --cmd "$extract_cmd --mem 6G" \
  #  --use-gpu $use_gpu \
  #  --nj $MAXNUMJOBS \
  #  --stage 0 \
  #  $nnet_dir \
  #  $test_data \
  #  $exp_dir/xvectors_test &
  wait;

  # Make language-int map (essentially just indexing the languages 0 to L)
  langs=($GP_EVAL_LANGUAGES)
  i=0
  for l in "${langs[@]}"; do
    echo $l $i
    i=$(expr $i + 1)
  done > conf/test_languages.list

  mkdir -p $exp_dir/results
  mkdir -p $exp_dir/classifier

  # Training the log reg model and classifying test set samples
  ./local/test_logistic_regression.sh \
    --test-dir $exp_dir/xvectors_eval \
    --model-dir $model_dir \
    --classification-file $exp_dir/results/classification \
    --test-utt2lang $eval_data/utt2lang \
    --languages conf/test_languages.list \
    > $exp_dir/classifier/logistic-regression.log


  ./local/compute_results.py \
    --classification-file $exp_dir/results/classification \
    --output-file $exp_dir/results/results \
    --language-list "$GP_ENROLL_LANGUAGES" \
    2>$exp_dir/results/compute_results.log

done
