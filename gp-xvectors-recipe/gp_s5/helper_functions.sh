whichMachine() {
	if [[ `echo ~` = "/home/samo" ]]; then
		echo "sam"
<<<<<<< HEAD
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/* ]]; then
		echo "dice"
	else
		echo "paul"
=======
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/s15/s1513472* ]]; then
		echo "dice_sam"
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/* ]]; then
		echo "dice_other"
	else
		echo "unrecognised_machine"
>>>>>>> 865b1195e742a386eec7c5d366f413349319936e
	fi
}