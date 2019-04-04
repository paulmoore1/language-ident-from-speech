#!/bin/sh

# RIRS number 2
./gp-xvectors-recipe/run.sh --config=new_baseline > outputs/new_baseline.txt
wait

./linux_run_extra_eval.sh
