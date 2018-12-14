#!/usr/bin/env bash

. path.sh

utils/slurm.pl --gpu 1 JOB=1:1 slurm-test.log ./dummy-code.sh
exit 0

sbatch \
    --nodelist=landonia04 \
    --gres=gpu:1 \
    --job-name=LID \
    --open-mode=append \
    --output=slurm-test-1.log \
    dummy-code.sh
