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


function createExcludeList () {
	backupjobid=$1
	workspace=$2

	#echo $backupjobid
	#echo $workspace
set -f

	excludeItems=( $(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | sed -n '/excludelist:/,$p' | sed '/time_estimation:/Q' | awk '{print $2}') )
	echo "Exclude List: " >> $workspace

	#echo "${excludeItems[@]}"
set +f
	for i in "${!excludeItems[@]}"
	do
		echo "  Item [$i]: ${excludeItems[$i]}" >> $workspace
		ExcludeList+="&exclude_list[$i]=${excludeItems[$i]}"
	done
}

function createIncludeList () {
	backupjobid=$1

	includeItems=( $(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | sed -n '/includelist:/,$p' | sed '/excludelist:/Q' | awk '{print $2}') )

	for i in "${!includeItems[@]}"
	do
		IncludeList+="&include_list[$i]=${includeItems[$i]}"
	done
}