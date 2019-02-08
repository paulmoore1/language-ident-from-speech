#!/bin/sh

usage="+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n
\t       This script runs all experiments in the configuration directory.\n
\t       Use like this: $0 <options>\n
\t       --config-dir\tConfig directory with all the experiment configurations,\n
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
  --run-all=*)
  run_all_cl=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --stage=*)
  stage_cl=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --exp-name=*)
  exp_name_cl=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  --exp-config=*)
  exp_config=`expr "X$1" : '[^=]*=\(.*\)'`; shift ;;
  *)  echo "Unknown argument: $1, exiting"; echo -e $usage; exit 1 ;;
  esac
done
echo -e $usage
