#!/bin/sh

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

sbatch \
  --nodelist=landonia[04] \
  --gres=gpu:2 \
  --job-name=$config_file \
  --mail-type=END \
  --mail-user=s1531206@ed.ac.uk \
  --open-mode=append \
  --output="${config_file}.out" \
  ./gp-xvectors-recipe/run.sh --home-dir=$PWD/gp_xvectors_recipe/ --exp-config="${config_file}.conf"
