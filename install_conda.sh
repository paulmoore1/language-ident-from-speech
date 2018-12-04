#!/usr/bin/env bash

if [ -x "$(command -v conda)" ]; then
  echo 'Conda installed and in PATH. Skipping installation.' >&2
  exit
else
  echo "Conda not installed. Installing it."
fi

mkdir $HOME/miniconda
cd $HOME/miniconda

wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ./miniconda.sh
bash ./miniconda.sh -b -p $HOME/miniconda -f
echo 'export PATH="$PATH:$HOME/miniconda/bin"' >> ~/.bashrc
source ~/.bashrc
