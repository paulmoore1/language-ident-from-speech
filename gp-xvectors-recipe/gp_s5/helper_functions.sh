whichMachine() {
	if [[ `echo ~` = "/home/samo" ]]; then
		echo "sam"
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/s15/s1513472* ]]; then
		echo "dice_sam"
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/* ]]; then
		echo "dice_other"
	else
		echo "unrecognised_machine"
	fi
}
