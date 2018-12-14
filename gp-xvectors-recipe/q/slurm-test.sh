#!/bin/bash
cd /mnt/mscteach_home/s1513472/language-ident-from-speech/gp-xvectors-recipe
. ./path.sh
( echo '#' Running on `hostname`
  echo '#' Started at `date`
  set | grep SLURM | while read line; do echo "# $line"; done
  echo -n '# '; cat <<EOF
./dummy-code.sh 
EOF
) >slurm-test.log
if [ "$CUDA_VISIBLE_DEVICES" == "NoDevFiles" ]; then
  ( echo CUDA_VISIBLE_DEVICES set to NoDevFiles, unsetting it... 
  )>>slurm-test.log
  unset CUDA_VISIBLE_DEVICES
fi
time1=`date +"%s"`
 ( ./dummy-code.sh  ) &>>slurm-test.log
ret=$?
sync || true
time2=`date +"%s"`
echo '#' Accounting: begin_time=$time1 >>slurm-test.log
echo '#' Accounting: end_time=$time2 >>slurm-test.log
echo '#' Accounting: time=$(($time2-$time1)) threads=1 >>slurm-test.log
echo '#' Finished at `date` with status $ret >>slurm-test.log
[ $ret -eq 137 ] && exit 100;
touch ./q/done.83228.$SLURM_ARRAY_TASK_ID
exit $[$ret ? 1 : 0]
## submitted with:
# sbatch --export=PATH  --ntasks-per-node=1  --gres=gpu:1 --time 4:0:0  --open-mode=append -e ./q/slurm-test.log -o ./q/slurm-test.log --array 1-1 /mnt/mscteach_home/s1513472/language-ident-from-speech/gp-xvectors-recipe/./q/slurm-test.sh >>./q/slurm-test.log 2>&1
