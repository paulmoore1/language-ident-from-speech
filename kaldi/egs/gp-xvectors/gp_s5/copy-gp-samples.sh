#!/bin/bash

# Copies samples (one speaker per language) from /group/corpora/public/...
# to home directory. Skips languages Chinese-Shanghai, Tamil and Hausa
# because the file structure of these is not the standard one (as for other
# languages).

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
    sampleSpeakerDir=$(ls "${gpPath}/${d}/adc/" | sort -n | head -1)
    speakerFile=$(ls "${gpPath}/${d}/spk/" | grep ".*$sampleSpeakerDir.*" | sort -n | head -1)
    transcriptFile=$(ls "${gpPath}/${d}/trl/" | grep ".*$sampleSpeakerDir.*" | sort -n | head -1)
    echo "  Copying audio for speaker: ${sampleSpeakerDir}"
    echo "  Copying speaker file: ${speakerFile}"
    echo "  Copying transcript file: ${transcriptFile}"
    cp -R $gpPath/$d/adc/$sampleSpeakerDir $d/adc
    cp $gpPath/$d/spk/$speakerFile $d/spk/
    cp $gpPath/$d/trl/$transcriptFile $d/trl/
done
