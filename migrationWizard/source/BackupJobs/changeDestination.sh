#!/bin/bash

###################################################################
#Script Name	: Migrate JB4 to JB5                                                                                             
#Description	: Script to migrate all supported configurations.                                                                                
#Args           :                                                                                           
#Author       	: Richard Ryan Marroquin                                                
#Email         	: richard@jetapps.com                                        
###################################################################

########## Global Variables ############
FILEPATH=$(pwd)/source/files
readarray -t currentJB5DestIds <<< "$(jetbackup5api -F listDestinations | grep -w "_id:" | awk '{print $2}')"
readarray -t currentJB5Dest <<< "$(jetbackup5api -F listDestinations | grep -w -A 2 "_id:" | grep -w "name:" | sed 's/      name: //')"

# Stores current JetBackup 5 Destination ID's and Names into Arrays

function printDestinations () {
	echo Please select a destination installed on JetBackup 5:
	for j in "${!currentJB5Dest[@]}"
	do
	printf "Destination #${j}: %s\n" "${currentJB5Dest[j]}"
	done
}

function setDestination () {
	newDest=$1

	while :;
	do
		read -p "Enter the number of the Destination you would like to use: " ID
		[[ $ID =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
		if (( $ID >= 0 && $ID < "${#currentJB5DestIds[@]}" )); then
    		echo "Using destination ${currentJB5Dest[$ID]}"
    		newDest="&destination[0]=${currentJB5DestIds[$ID]}"
    		break
  		else
    		echo "number out of range, try again"
  		fi
	done
}
