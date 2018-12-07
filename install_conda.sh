#!/usr/bin/env bash

source ~/.bashrc

if [ -x "$(command -v conda)" ]; then
  echo 'Conda installed and in PATH. Skipping installation.' >&2
else
  echo "Conda not installed. Installing it."
  mkdir $HOME/miniconda
  pushd $HOME/miniconda

  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ./miniconda.sh
  bash ./miniconda.sh -b -p $HOME/miniconda -f
  # echo 'export PATH="$PATH:$HOME/miniconda/bin"' >> ~/.bashrc
  echo ". $HOME/miniconda/etc/profile.d/conda.sh" >> ~/.bashrc
  source ~/.bashrc
  popd
fi

if [ ! "$(conda env list | grep lid)" ]; then 
  echo "Conda environment 'lid' does not exist. Creating it."
  conda env create -f ./environment.yml
else
  echo "Conda environment 'lid' exists already."
fi
