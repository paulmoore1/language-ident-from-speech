#!/bin/sh

# RIRS number 2
./gp-xvectors-recipe/run.sh --config=da_rirs_tr_500 > outputs/da_rirs_tr_500.txt
wait

./gp-xvectors-recipe/run.sh --config=da_rirs_tr_1000 > outputs/da_rirs_tr_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_rirs_tr_10000 > outputs/da_rirs_tr_10000.txt
wait

./linux_run_extra_eval.sh

#RIRS clean
./gp-xvectors-recipe/run.sh --config=da_rirs_clean_tr_500 > outputs/da_rirs_clean_tr_500.txt
wait

./gp-xvectors-recipe/run.sh --config=da_rirs_clean_tr_1000 > outputs/da_rirs_clean_tr_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_rirs_clean_tr_10000 > outputs/da_rirs_clean_tr_10000.txt
wait

./linux_run_extra_eval.sh

# Aug clean number 2

./gp-xvectors-recipe/run.sh --config=da_aug_clean_tr_500 > outputs/da_aug_clean_tr_500.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_clean_tr_1000 > outputs/da_aug_clean_tr_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_clean_tr_10000 > outputs/da_aug_clean_tr_10000.txt
wait

./linux_run_extra_eval.sh

# Aug RIRS number 2

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_tr_500 > outputs/da_aug_rirs_tr_500.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_tr_1000 > outputs/da_aug_rirs_tr_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_tr_10000 > outputs/da_aug_rirs_tr_10000.txt
wait

./linux_run_extra_eval.sh


# Aug RIRS clean number 2

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_clean_tr_500 > outputs/da_aug_rirs_clean_tr_500.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_clean_tr_1000 > outputs/da_aug_rirs_clean_tr_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=da_aug_rirs_clean_tr_10000 > outputs/da_aug_rirs_clean_tr_10000.txt
wait

./linux_run_extra_eval.sh
