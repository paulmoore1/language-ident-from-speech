#!/bin/sh
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=Standard
#SBATCH --gres=gpu:2
#SBATCH --time=08:00:00
#SBATCH --output=outputs/lre_tr_1000_en_1000.out
#SBATCH --job-name=lre_tr_1000_en_1000
#SBATCH --mail-type=END
#SBATCH --mail-user=lapilosew2003@gmail.com
#SBATCH --open-mode=append

config_file=lre_tr_1000_en_1000

export STUDENT_ID=$(whoami)
export HOME_DIR=/home/${STUDENT_ID}/language-ident-from-speech

cd $HOME_DIR

mkdir -p ${HOME_DIR}/outputs
outputs_dir=${HOME_DIR}/outputs
# Remove output file if it exists already
echo "New expt" > $outputs_dir/"${config_file}.out"

recipe_dir=${HOME_DIR}/gp-xvectors-recipe

./gp-xvectors-recipe/run.sh --home-dir=$recipe_dir --exp-config="${config_file}.conf"
