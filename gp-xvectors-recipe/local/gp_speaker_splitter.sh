
# How train/eval/test sets are made in GP: 
# "The sets split up in a way that no speaker 
# appears in more than one group and no article 
# was read by two speakers from different groups."

# AR: OK
# BG: No articles
# CH: OK
# CR: OK
# CZ: Weird articles
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

for L in Arabic Bulgarian Chinese-Shanghai/Wu Croatian Czech French German Hausa Japanese Korean Mandarin Polish Portuguese Russian Spanish Swahili Swedish Tamil Thai Turkish Ukrainian Vietnamese; do
	echo "### $L ###"
	if [ ! -s $L/spk ]; then
		echo "spk data not found"
	fi
	for spk_file in $L/spk/*.spk; do
		spk_num=$(echo ">$spk_file<" | sed -En "s/.*[A-Z]+([0-9]+)\..*/\1/p")
		# echo $spk_num
		articles=$(cat $spk_file | grep -E ';ARTICLE READORDER:' | sed -En "s/(;ARTICLE READORDER:|\n)//p" | tr -d '\012\015')
		gender=$(cat $spk_file | grep -E ';SEX:' | sed -En "s/;SEX:([a-z]+).*/\1/p" | tr -d '\012\015')
		if [[ -z "$articles" || "$articles" == "Unknown"* && -z "$gender" ]]; then
			# echo "no articles for spk ${spk_num}"
			continue
		else
			echo "${spk_num}|${gender}|${articles}"
		fi
	done
done
