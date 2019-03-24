#!/bin/sh

./gp-xvectors-recipe/run.sh --config=da_aug_tr_500 > da_aug_tr_500.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_1000 > da_aug_tr_1000.txt
wait
./gp-xvectors-recipe/run.sh --config=da_aug_tr_5000 > da_aug_tr_5000.txt
wait

./linux_run_lre.sh
