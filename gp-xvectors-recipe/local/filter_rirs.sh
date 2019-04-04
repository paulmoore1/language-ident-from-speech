#!/bin/sh

# Filters out the RIRS noises from the augmented data. Necessary when MUSAN was dropped
data_dir=~/gp-data/all_preprocessed

lang_dirs=$(find $data_dir -name *train_aug -not -path "*log*" -type d)
for lang_dir in $lang_dirs; do
  parent_dir=$(dirname "$lang_dir")
  lang=$(basename $parent_dir)
  train_rirs_dir=$parent_dir/${lang}_train_rirs
  if [ ! -d $train_rirs_dir ]; then
    cp -r $lang_dir $train_rirs_dir
  fi
  cat $train_rirs_dir/utt2spk | grep -w '.*-reverb.*' > $train_rirs_dir/utt2spk.temp
  mv $train_rirs_dir/utt2spk.temp $train_rirs_dir/utt2spk
  utils/filter_scp.pl $train_rirs_dir/utt2spk $train_rirs_dir/wav.scp > $train_rirs_dir/wav.scp.temp
  mv $train_rirs_dir/wav.scp.temp $train_rirs_dir/wav.scp
  utils/fix_data_dir.sh $train_rirs_dir
  sed -e 's?[0-9]*$??' $train_rirs_dir/utt2spk > $train_rirs_dir/utt2lang
  local/utt2lang_to_lang2utt.pl $train_rirs_dir/utt2lang \
  > $train_rirs_dir/lang2utt
  # Used for fixing utt2num frames in all folders if need be
  utils/data/get_utt2num_frames.sh $train_rirs_dir
  utils/combine_data.sh --extra-files 'utt2num_frames' ${train_rirs_dir}_combined $parent_dir/${lang}_train $train_rirs_dir
  utils/combine_data.sh --extra-files 'utt2num_frames' ${train_rirs_dir}_aug_combined $parent_dir/${lang}_train_speeds ${train_rirs_dir}_combined
done
