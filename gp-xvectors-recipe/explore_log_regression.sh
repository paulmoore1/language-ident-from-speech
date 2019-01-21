#!/bin/bash
# Use to investigae values for logistic regression. Assumes plda model already trained
# Stores results in /expname/results
EXPNAME="test_expt"
stage=8
run_all=true
GP_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU WU VN"

. ./path.sh

declare -a max_steps_vals=(20 30 40 50 60 70 80 90 100)
declare -a normalizer_vals=(0.0001 0.001 0.0025 0.005 0.01)
declare -a mix_up_vals=(19 50 100 150 200 250 300)

DATADIR="${DATADIR}/baseline"
exp_dir=$DATADIR/exp

langs=($GP_LANGUAGES)
i=0
for l in "${langs[@]}"; do
  echo $l $i
  i=$(expr $i + 1)
done > conf/test_languages.list

mkdir -p $DATADIR/find_log_values/log


for max_steps in ${max_steps_vals[@]}; do
  for normalizer in ${normalizer_vals[@]}; do
    EXPNAME="explore_log_max_steps=${max_steps}_normalizer=${normalizer}"
    test_dir=$DATADIR/find_log_values/$EXPNAME

#    echo "#### Training logistic regression classifier and classifying test utterances. ####"
#    echo "Max steps = $max_steps  Normalizer = $normalizer"
#    mkdir -p $test_dir/results
#    mkdir -p $test_dir/classifier
#
#    logistic_regression_conf_text="--max-steps=$max_steps\n--normalizer=$normalizer\n--mix-up=200\n--power=0.15"
#    echo -e $logistic_regression_conf_text > conf/logistic-regression.conf

    # Training the log reg model and classifying test set samples
#    ./local/run_logistic_regression.sh \
#      --prior-scale 0.70 \
#      --conf conf/logistic-regression.conf \
#      --train-dir $exp_dir/xvectors_enroll \
#      --test-dir $exp_dir/xvectors_eval \
#      --model-dir $test_dir/classifier \
#      --classification-file $test_dir/results/classification \
#      --train-utt2lang $DATADIR/enroll/utt2lang \
#      --test-utt2lang $DATADIR/eval/utt2lang \
#      --languages conf/test_languages.list \
#      > $test_dir/classifier/logistic-regression.log
#
#    echo "#### Calculating results. ####"
#
#    python ./local/compute_results.py \
#      --classification-file $test_dir/results/classification \
#      --output-file $test_dir/results/results \
#      --language-list "$GP_LANGUAGES" \
#      2>$test_dir/results/compute_results.log
    echo "Max steps = $max_steps  Normalizer = $normalizer" >> $DATADIR/find_log_values/log/results.log
    cat $test_dir/results/results | grep --regexp="Accuracy: 0.[0-9]*" >> $DATADIR/find_log_values/log/results.log
    cat $test_dir/results/results | grep --regexp="C_primary value: 0.[0-9]*" >> $DATADIR/find_log_values/log/results.log
  done
done
exit

  for mix_up in ${mix_up_vals[@]}; do
    for power in ${power_vals[@]}; do
      EXPNAME="explore_log_mix-up=${mix_up}_power=${power}"
      test_dir=$DATADIR/find_log_values/$EXPNAME
      echo "#### Training logistic regression classifier and classifying test utterances. ####"
      echo "#Mixture models = $mix_up  Power = $power"
      mkdir -p $test_dir/results
      mkdir -p $test_dir/classifier

      logistic_regression_conf_text="--max-steps=!FIXME\n--normalizer=!FIXME\n--mix-up=$mix_up\n--power=$power"
      echo -e $logistic_regression_conf_text > conf/logistic-regression.conf

      # Training the log reg model and classifying test set samples
      ./local/run_logistic_regression.sh \
        --prior-scale 0.70 \
        --conf conf/logistic-regression.conf \
        --train-dir $exp_dir/xvectors_enroll \
        --test-dir $exp_dir/xvectors_eval \
        --model-dir $test_dir/classifier \
        --classification-file $test_dir/results/classification \
        --train-utt2lang $DATADIR/enroll/utt2lang \
        --test-utt2lang $DATADIR/eval/utt2lang \
        --languages conf/test_languages.list \
        > $test_dir/classifier/logistic-regression.log

      echo "#### Calculating results. ####"

      python ./local/compute_results.py \
        --classification-file $test_dir/results/classification \
        --output-file $test_dir/results/results \
        --language-list "$GP_LANGUAGES" \
        2>$test_dir/results/compute_results.log
      done >> $DATADIR/find_log_values/log/output.log
    done
