#!/bin/bash
data_dir=~/gp-data

expt_dirs=$(find $data_dir -maxdepth 1 -mindepth 1 -type d \
-not -path "*old_aug*" \
-not -path "*all_preprocessed*")
for dir in $expt_dirs; do
  if [ ! -f $dir/exp/results/results ]; then
    echo "No results found for $dir"
    continue
  fi
  expname=$(basename $dir)
  if [[ $expname == ad_all_tr* ]]; then
    GP_EVAL_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU WU VN"
  elif [[ $expname == ad_slavic_tr* ]]; then
    GP_EVAL_LANGUAGES="BG CR CZ PO RU"
  else
    GP_EVAL_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU VN"
  fi
  echo -e "use_model_from=$expname\nGP_EVAL_LANGUAGES=\"$GP_EVAL_LANGUAGES\"" \
  > gp-xvectors-recipe/conf/eval_configs/expconf.conf
  echo "Trying $expname"
  if [ $(ls $dir/exp/results | wc -l) != 9 ]; then
  ./gp-xvectors-recipe/run_extra_eval.sh --config=expconf
  wait;
  echo "Done"
  else
  echo "Finished already"
  fi
done
