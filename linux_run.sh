#!/bin/sh
./gp-xvectors-recipe/run.sh --config=da_rirs_tr_500 > outputs/da_rirs_tr_500.txt
wait
./gp-xvectors-recipe/run.sh --config=da_rirs_tr_1000 > outputs/da_rirs_tr_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_rirs_tr_10000 > outputs/da_rirs_tr_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_rirs_clean_tr_500 > outputs/da_rirs_clean_tr_500.txt
wait
./gp-xvectors-recipe/run.sh --config=da_rirs_clean_tr_1000 > outputs/da_rirs_clean_tr_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_rirs_clean_tr_10000 > outputs/da_rirs_clean_tr_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_tr_500 > outputs/da_aug_rirs_tr_500.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_rirs_tr_1000 > outputs/da_aug_rirs_tr_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_rirs_tr_10000 > outputs/da_aug_rirs_tr_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_clean_tr_500 > outputs/da_aug_rirs_clean_tr_500.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_rirs_clean_tr_1000 > outputs/da_aug_rirs_clean_tr_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_rirs_clean_tr_10000 > outputs/da_aug_rirs_clean_tr_10000.txt
wait

#./linux_run_extra_eval.sh

./gp-xvectors-recipe/run.sh --config=lre_tr_500_en_500 > outputs/lre_tr_500_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_500 > outputs/lre_tr_1000_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_500 > outputs/lre_tr_500_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_500 > outputs/lre_tr_1000_en_500.txt
wait

./linux_run_extra_eval.sh
