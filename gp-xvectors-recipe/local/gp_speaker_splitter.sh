#!/bin/bash -u

# How train/eval/test sets are made in GP: 
# "The sets split up in a way that no speaker 
# appears in more than one group and no article 
# was read by two speakers from different groups."

# AR: OK
# BG: No articles
# CH: OK
# CR: OK
# CZ: OK (weird articles)
# FR: No articles
# GE: No articles
# JA: OK
# KO: OK
# PL: No articles
# PO: OK
# RU: OK
# SP: OK
# SW: OK
# TA: No data
# TH: No articles
# TU: OK
# VN: No articles
# WU: OK

LANGMAP=conf/lang_codes.txt
GP_CORPUS=/disk/scratch/lid/global_phone

mkdir -p speakers

for L in AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TA TH TU VN WU; do
	echo "### $L ###"

	full_name=`awk '/'$L'/ {print $2}' $LANGMAP`;
	spk_path=$full_name
	if [ "$full_name" == "Chinese-Shanghai" ]; then
		spk_path=$full_name/Wu
	fi
	spk_path=$GP_CORPUS/$spk_path/spk
	
	# if spk data not present
	if [ ! -s $spk_path ] || [ -z "$(ls -A $spk_path)" ]; then
		continue
	fi
	
	for spk_file in $spk_path/*.spk; do
		spk_num=$(echo ">$spk_file<" | sed -En "s/.*[A-Z]+([0-9]+)\..*/\1/p")
		articles=$(cat $spk_file | grep -E ';ARTICLE READORDER:' | sed -En "s/(;ARTICLE READORDER:|\n)//p" | tr -d '\012\015')
		gender=$(cat $spk_file | grep -E ';SEX:' | sed -En "s/;SEX:([a-z]+).*/\1/p" | tr -d '\012\015')
		
		if [[ -z "$articles" || "$articles" == "Unknown"* && -z "$gender" ]]; then
			# no articles for spk
			continue
		else
			echo "${spk_num}|${gender}|${articles}" >> speakers/${L}_spk_metadata
		fi
	done
done
