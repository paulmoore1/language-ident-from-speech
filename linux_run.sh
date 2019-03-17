#!/bin/sh
./gp-xvectors-recipe/run.sh --config=da_aug_tr_500_baseline > output_da_aug_tr_500_baseline.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_1000_baseline > output_da_aug_tr_1000_baseline.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_5000_baseline > output_da_aug_tr_5000_baseline.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_10000_baseline > output_da_aug_tr_10000_baseline.txt
wait
./gp-xvectors-recipe/run.sh --config=da_clean_tr_500 > output_da_clean_tr_500.txt
wait
./gp-xvectors-recipe/run.sh --config=da_clean_tr_1000 > output_da_clean_tr_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_clean_tr_5000 > output_da_clean_tr_5000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_clean_tr_10000 > output_da_clean_tr_10000.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_fr > output_ad_all_tr_no_fr.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_tu > output_ad_all_tr_no_tu.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_sp > output_ad_all_tr_no_sp.txt
wait
