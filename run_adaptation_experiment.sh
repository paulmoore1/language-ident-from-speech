#!/bin/sh
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=LongJobs
#SBATCH --gres=gpu:2
#SBATCH --time=3-08:00:00
#SBATCH --output=outputs/ad_all_tr_no_ar.out
#SBATCH --job-name=ad_all_tr_no_ar
#SBATCH --mail-type=END
#SBATCH --mail-user=lapilosew2003@gmail.com
#SBATCH --open-mode=append

# This is for experiments involving data augmentation
# NB check that data augmentation actually occurs first!!!
config_file=ad_all_tr_no_ar

export STUDENT_ID=$(whoami)
export HOME_DIR=/home/${STUDENT_ID}/language-ident-from-speech

cd $HOME_DIR

mkdir -p ${HOME_DIR}/outputs
outputs_dir=${HOME_DIR}/outputs
# Remove output file if it exists already
echo "New expt" > $outputs_dir/"${config_file}.out"

recipe_dir=${HOME_DIR}/gp-xvectors-recipe

./gp-xvectors-recipe/run.sh --home-dir=$recipe_dir --exp-config="${config_file}.conf"
