#!/bin/sh
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --partition=LongJobs
#SBATCH --gres=gpu:2
#SBATCH --time=3-08:00:00
#SBATCH --output=outputs/lre_tr_500_en_500_2.out
#SBATCH --job-name=lre_tr_500_en_500_2
#SBATCH --mail-type=END
#SBATCH --mail-user=lapilosew2003@gmail.com
#SBATCH --open-mode=append

export STUDENT_ID=$(whoami)
export HOME_DIR=/home/${STUDENT_ID}/language-ident-from-speech

cd $HOME_DIR

usage="+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
\t       This script runs a single experiment from the configuration directory.\n
\t       Use like this: $0 <options>\n
\t       --config-file=FILE\tConfig file with all the experiment configurations,\n
\t       \t\t\tsee conf/exp_default.conf for an example.\n
\t       \t\t\tNOTE: Where arguments are passed on the command line,\n
\t       \t\t\tthe values overwrite those found in the config file.\n\n
\t       If no stage number is provided, either all stages\n
\t       will be run (--run-all=true) or no stages at all.\n
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
while [ $# -gt 0 ];
do
  case "$1" in
  --help) echo -e $usage; exit 0 ;;
  --config-file=*)
  config_file=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done

mkdir -p ${HOME_DIR}/outputs
outputs_dir=${HOME_DIR}/outputs
# Remove output file if it exists already
rm -f $outputs_dir/"${config_file}.out"

recipe_dir=${HOME_DIR}/gp-xvectors-recipe

#(echo 'YourDicePassword' | nohup longjob -28day -c './run.sh --exp-config=conf/exp_default.conf --stage=1' &> nohup-baseline.out ) &
./gp-xvectors-recipe/run.sh --home-dir=$recipe_dir --exp-config="lre_tr_500_en_500.conf"
