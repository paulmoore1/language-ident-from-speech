#!/bin/sh
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=LongJobs
#SBATCH --gres=gpu:2
#SBATCH --time=3-08:00:00
#SBATCH --output=outputs/data_prep.out
#SBATCH --job-name=data_prep
#SBATCH --mail-type=END
#SBATCH --mail-user=lapilosew2003@gmail.com
#SBATCH --open-mode=append

export STUDENT_ID=$(whoami)
export HOME_DIR=/home/${STUDENT_ID}/language-ident-from-speech/gp-xvectors-recipe

cd $HOME_DIR

mkdir -p ${HOME_DIR}/outputs
outputs_dir=${HOME_DIR}/outputs
# Remove output file if it exists already
echo "New expt" > $outputs_dir/"${config_file}.out"

./prep_all_data.sh