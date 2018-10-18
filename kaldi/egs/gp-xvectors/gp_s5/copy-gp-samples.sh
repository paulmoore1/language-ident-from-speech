#!/bin/bash

# Copies samples (one speaker per language) from /group/corpora/public/...
# to home directory. Skips languages Chinese-Shanghai, Tamil and Hausa
# because the file structure of these is not the standard one (as for other
# languages).

num_speakers_per_language=3

gpPath=/group/corpora/public/global_phone
arr=($(find "$gpPath" -maxdepth 1 -mindepth 1 -name "[[:upper:]]*" -type d -printf '%f\n'))
toExclude=( Dictionaries )

for d in "${arr[@]/$toExclude}" ; do
    if [[ "$d" = "" ]]; then
    echo "Skipping invalid language"
        continue
    fi
    echo "Copying language: ${d}"
    mkdir $d/
    mkdir $d/adc/
    mkdir $d/spk/
    mkdir $d/trl/
    sampleSpeakers=($(ls "${gpPath}/${d}/adc/" | sort -n | head -n 3))
    echo "  Copying speakers: ${sampleSpeakers[*]}"
    
    for speakerDir in "${sampleSpeakers[@]}"; do
        speakerFile=$(ls "${gpPath}/${d}/spk/" | grep ".*$speakerDir.*" | sort -n | head -1)
        transcriptFile=$(ls "${gpPath}/${d}/trl/" | grep ".*$speakerDir.*" | sort -n | head -1)
        echo "      Copying audio for speaker: ${speakerDir}"
        echo "      Copying speaker file: ${speakerFile}"
        echo "      Copying transcript file: ${transcriptFile}"
        cp -R $gpPath/$d/adc/$speakerDir $d/adc
        cp $gpPath/$d/spk/$speakerFile $d/spk/
        cp $gpPath/$d/trl/$transcriptFile $d/trl/
    done
done

echo "Now copying the dictionaries"
rsync -av --exclude='*.pdf' --exclude='*.dict' --exclude='*.trl' $gpPath/Dictionaries .