#!/bin/sh

# RIRS number 2

#./gp-xvectors-recipe/run.sh --config=new_baseline > outputs/new_baseline.txt
#wait

#./gp-xvectors-recipe/run.sh --config=new_baseline > outputs/new_baseline.txt
#wait


#exit
# Remember to remove silence removal my dude

#Last aug clean
./gp-xvectors-recipe/run.sh --config=da_aug_clean_tr_5000 > outputs/da_aug_clean_tr_5000.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ar > outputs/ad_all_tr_no_ar.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_bg > outputs/ad_all_tr_no_bg.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ch > outputs/ad_all_tr_no_ch.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_cr > outputs/ad_all_tr_no_cr.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_cz > outputs/ad_all_tr_no_cz.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_fr > outputs/ad_all_tr_no_fr.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ge > outputs/ad_all_tr_no_ge.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ja > outputs/ad_all_tr_no_ja.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ko > outputs/ad_all_tr_no_ko.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_pl > outputs/ad_all_tr_no_pl.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_po > outputs/ad_all_tr_no_po.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_ru > outputs/ad_all_tr_no_ru.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_sp > outputs/ad_all_tr_no_sp.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_sw > outputs/ad_all_tr_no_sw.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_th > outputs/ad_all_tr_no_th.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_tu > outputs/ad_all_tr_no_tu.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_vn > outputs/ad_all_tr_no_vn.txt
wait

./gp-xvectors-recipe/run.sh --config=ad_all_tr_no_wu > outputs/ad_all_tr_no_wu.txt
wait

./linux_run_extra_eval.sh
