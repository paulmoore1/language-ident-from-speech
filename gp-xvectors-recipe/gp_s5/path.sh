# This contains the locations of the tools and data required for running
# the GlobalPhone experiments.
source ./helper_functions.sh

export LC_ALL=C  # For expected sorting and joining behaviour
# [ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
# KALDISRC=$KALDI_ROOT/src
# KALDIBIN=$KALDISRC/bin:$KALDISRC/featbin:$KALDISRC/fgmmbin:$KALDISRC/fstbin
# KALDIBIN=$KALDIBIN:$KALDISRC/gmmbin:$KALDISRC/latbin:$KALDISRC/nnetbin
# KALDIBIN=$KALDIBIN:$KALDISRC/sgmm2bin:$KALDISRC/lmbin
# FSTBIN=$KALDI_ROOT/tools/openfst/bin
# LMBIN=$KALDI_ROOT/tools/irstlm/bin
[ -d $PWD/local ] || { echo "Error: 'local' subdirectory not found."; }
[ -d $PWD/utils ] || { echo "Error: 'utils' subdirectory not found."; }
[ -d $PWD/steps ] || { echo "Error: 'steps' subdirectory not found."; }

export kaldi_local=$PWD/local
export kaldi_utils=$PWD/utils
export kaldi_steps=$PWD/steps

SCRIPTS=$kaldi_local:$kaldi_utils:$kaldi_steps
# export PATH=$PATH:$KALDIBIN:$FSTBIN:$LMBIN:$SCRIPTS
export PATH=$PATH:$SCRIPTS

# If the correct version of shorten and sox are not on the path,
# the following will be set by local/gp_check_tools.sh
SHORTEN_BIN=/afs/inf.ed.ac.uk/user/s15/s1531206/language-ident-from-speech/gp-xvectors-recipe/gp_s5/tools/shorten-3.6.1/bin
# e.g. $PWD/tools/shorten-3.6.1/bin
SOX_BIN=/afs/inf.ed.ac.uk/user/s15/s1531206/language-ident-from-speech/gp-xvectors-recipe/gp_s5/tools/sox-14.3.2/bin
# e.g. $PWD/tools/sox-14.3.2/bin
export PATH=$SHORTEN_BIN:$PATH
export PATH=$SOX_BIN:$PATH

if [[ $(whichMachine) = "sam" ]]; then
	GP_CORPUS=/afs/inf.ed.ac.uk/user/s15/s1513472/global_phone/
elif [[ $(whichMachine) = "dice_sam" ]]; then
	GP_CORPUS=~/global_phone/
	#GP_CORPUS=/group/corpora/public/global_phone
elif [[ $(whichMachine) = "dice_other" ]]; then
	GP_CORPUS=/group/corpora/public/global_phone
else
	echo "NOT IMPLEMENTED: setting GlobalPhone directory."
fi
export PATH=$SHORTEN_BIN:$PATH
export PATH=$SHORTEN_BIN:$PATH
export PATH=$SHORTEN_BIN:$PATH
