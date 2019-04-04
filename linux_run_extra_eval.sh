#!/bin/bash
data_dir=~/gp-data

expt_dirs=$(find $data_dir -maxdepth 1 -mindepth 1 -type d \
-not -path "*old_aug*" \
-not -path "*all_preprocessed*")
for dir in $expt_dirs; do
  if [ ! -f $dir/exp/results/results_30s ]; then
    echo "No 30s results found for $dir !"
    continue
  fi
  expname=$(basename $dir)
  if [[ $expname == ad_all_tr* ]]; then
    #GP_EVAL_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU WU VN"
    continue
  elif [[ $expname == ad_slavic_tr* ]]; then
    #GP_EVAL_LANGUAGES="BG CR CZ PL RU"
    continue
  elif [[ $expname == da_* ]]; then
    GP_EVAL_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU VN"
  elif [[ $expname == lre_* ]]; then
    continue
  else
    GP_EVAL_LANGUAGES="AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU WU VN"
  fi
  echo -e "use_model_from=$expname\nGP_EVAL_LANGUAGES=\"$GP_EVAL_LANGUAGES\"" \
  > gp-xvectors-recipe/conf/eval_configs/expconf.conf
  echo "Trying $expname"
  if [ $(ls $dir/exp/results | wc -l) -ne 9 ]; then
    echo "Adding 3s and 10s results..."
    ./gp-xvectors-recipe/run_extra_eval.sh --config=expconf
    wait;
    if [ $(ls $dir/exp/results | wc -l) -eq 9 ]; then
      echo "Finished getting extra X-vectors" | mail -v -s "$expname" paulmooreukmkok@gmail.com
    else
      echo "Error getting extra results"  | mail -v -s "$expname" paulmooreukmkok@gmail.com
    fi
  else
  echo "#### Finished already ####"
  fi
done
