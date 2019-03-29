#!/bin/sh

#Final full training expt
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_500 > outputs/lre_tr_10000_en_500.txt
wait

# Extra enrollment expts

./gp-xvectors-recipe/run.sh --config=lre_tr_500_en_1000 > outputs/lre_tr_500_en_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_1000 > outputs/lre_tr_1000_en_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_1000 > outputs/lre_tr_5000_en_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_1000 > outputs/lre_tr_10000_en_1000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_500_en_5000 > outputs/lre_tr_500_en_5000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_5000 > outputs/lre_tr_1000_en_5000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_5000 > outputs/lre_tr_5000_en_5000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_5000 > outputs/lre_tr_10000_en_5000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_500_en_10000 > outputs/lre_tr_500_en_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_10000 > outputs/lre_tr_1000_en_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_10000 > outputs/lre_tr_5000_en_10000.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_10000 > outputs/lre_tr_10000_en_10000.txt
wait


./linux_run_extra_eval.sh
