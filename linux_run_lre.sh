#!/bin/sh

./gp-xvectors-recipe/run.sh --config=lre_tr_500_en_500 > outputs/lre_tr_500_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_500 > outputs/lre_tr_1000_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_500 > outputs/lre_tr_500_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_500 > outputs/lre_tr_1000_en_500.txt
wait

./linux_run_extra_eval.sh

exit

./gp-xvectors-recipe/run.sh --config=lre_tr_500_en_500 > outputs/lre_tr_500_en_500.txt
wait





./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_500 > outputs/lre_tr_1000_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_500 > outputs/lre_tr_1000_en_500.txt
wait


:<<TEMP
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_1000 > outputs/lre_tr_1000_en_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_1000_2 > outputs/lre_tr_1000_en_1000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_1000_3 > outputs/lre_tr_1000_en_1000_3.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_5000 > outputs/lre_tr_1000_en_5000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_5000_2 > outputs/lre_tr_1000_en_5000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_5000_3 > outputs/lre_tr_1000_en_5000_3.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_10000 > outputs/lre_tr_1000_en_10000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_10000_2 > outputs/lre_tr_1000_en_10000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_1000_en_10000_3 > outputs/lre_tr_1000_en_10000_3.txt
wait

./linux_run_extra_eval.sh
TEMP

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_500 > outputs/lre_tr_5000_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_500 > outputs/lre_tr_5000_en_500.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_500 > outputs/lre_tr_5000_en_500.txt
wait

:<<TEMP
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_1000 > outputs/lre_tr_5000_en_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_1000_2 > outputs/lre_tr_5000_en_1000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_1000_3 > outputs/lre_tr_5000_en_1000_3.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_5000 > outputs/lre_tr_5000_en_5000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_5000_2 > outputs/lre_tr_5000_en_5000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_5000_3 > outputs/lre_tr_5000_en_5000_3.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_10000 > outputs/lre_tr_5000_en_10000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_10000_2 > outputs/lre_tr_5000_en_10000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_5000_en_10000_3 > outputs/lre_tr_5000_en_10000_3.txt
wait


./linux_run_extra_eval.sh
TEMP

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_500 > outputs/lre_tr_10000_en_500.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_500 > outputs/lre_tr_10000_en_500.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_500 > outputs/lre_tr_10000_en_500.txt
wait


:<<TEMP
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_1000 > outputs/lre_tr_10000_en_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_1000_2 > outputs/lre_tr_10000_en_1000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_1000_3 > outputs/lre_tr_10000_en_1000_3.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_5000 > outputs/lre_tr_10000_en_5000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_5000_2 > outputs/lre_tr_10000_en_5000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_5000_3 > outputs/lre_tr_10000_en_5000_3.txt
wait

./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_10000 > outputs/lre_tr_10000_en_10000.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_10000_2 > outputs/lre_tr_10000_en_10000_2.txt
wait
./gp-xvectors-recipe/run.sh --config=lre_tr_10000_en_10000_3 > outputs/lre_tr_10000_en_10000_3.txt
wait

./linux_run_extra_eval.sh
TEMP
