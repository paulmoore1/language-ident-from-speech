#!/bin/sh
./gp-xvectors-recipe/run.sh --config=ad_slavic_tr_all > output_ad_slavic_tr_all.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_slavic_tr_no_cr > output_ad_slavic_tr_no_cr.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_slavic_tr_no_cr > output_ad_slavic_tr_no_cz.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_slavic_tr_no_pl > output_ad_slavic_tr_no_pl.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_5000 > output_da_aug_5000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_10000 > output_da_aug_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ch > output_ad_all_tr_no_ch.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_fr > output_ad_all_tr_no_fr.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_cz > output_ad_all_tr_no_cz.txt
wait
./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ge > output_ad_all_tr_no_ge.txt
wait
