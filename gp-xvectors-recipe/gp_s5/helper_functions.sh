whichMachine() {
	if [[ `echo ~` = "/home/samo" ]]; then
		echo "sam"
	elif [[ `echo ~` = /afs/inf.ed.ac.uk/user/* ]]; then
		echo "dice"
	else
		echo "paul"
	fi
}