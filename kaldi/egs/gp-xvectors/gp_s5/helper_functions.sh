whichMachine() {
	if [[ `echo ~` = "/home/samo" ]]; then
		echo "sam"
	else
		echo "paul"
	fi
}