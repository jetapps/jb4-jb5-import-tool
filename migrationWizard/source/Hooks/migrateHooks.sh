#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

############## GLOBAL VARIABLES ##################
FILEPATH=$(pwd)/source/files
JB4HookArgs=("positiontype" "position" "script" "name")
supportedTypes=("1" "3" "4" "5" "8")
CMD=""
Workspace=$(pwd)/source/tmp

source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh
#################################################

JB4HookLists=($(jetapi backup -F listHooks | grep _id | awk '{print $2}'))
declare -A ARGS

#echo "Length of the array ${#JB4HookLists[@]}"

if [ "${#JB4HookLists[@]}" -ne 0 ]; then
	echo "Collecting Hook Data: "
	for i in "${!JB4HookLists[@]}"
	do
	#check if position type is supported
		echo
		echo "  Hook [$i]: ${JB4HookLists[$i]}"
		echo
		ARGS[position]=$(jetapi backup -F getHook -D "_id=${JB4HookLists[$i]}" | grep -w "position" | sed "s/.*position: //")
		if [[ " ${supportedTypes} " =~ " ${ARGS[position]} " ]]
		then
			#create tmp file
			tmpSpace="$Workspace/Hook_${JB4HookLists[$i]}"
			touch $tmpSpace
			echo "Data for Hook: " >> $tmpSpace
			echo "" >> $tmpSpace

			for key in "${JB4HookArgs[@]}"
			do
				#Store configuration data in tmp file for review
				ARGS["${key}"]=$(jetapi backup -F getHook -D "_id=${JB4HookLists[$i]}" | grep -w ${key} | sed "s/  ${key}: //")
				echo "  ${key} : ${ARGS[${key}]}"
				echo "${key} : ${ARGS[${key}]}" >> $tmpSpace
			done
			#Store api command in tmp file
			echo "" >> $tmpSpace
			CMD="jetbackup5api -F manageHook -D 'action=create&name=${ARGS[name]}&position_type=${ARGS[positiontype]}&position=${ARGS[position]}&script=${ARGS[script]}&disabled=1'"
			echo $CMD >> $tmpSpace
		else
			printWarning
			echo "  Hook type ${ARGS[position]} is not supported on JetBackup 5."
			echo "  Please refer to the manual or visit https://docs.jetbackup.com/v5.1/adminpanel/hooks.html for more information."
		fi
	done
else
	printWarning
	echo "There are no hooks to migrate, moving to settings."
	echo
fi