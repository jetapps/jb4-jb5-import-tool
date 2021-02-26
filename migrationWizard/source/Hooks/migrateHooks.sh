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
CMD=""

source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh
#################################################

JB4HookLists=($(jetapi backup -F listHooks | grep _id | awk '{print $2}'))
declare -A ARGS

echo "Length of the array ${#JB4HookLists[@]}"

if [ "${#JB4HookLists[@]}" -ne 0 ]; then
	for i in "${!JB4HookLists[@]}"
	do
		for key in "${JB4HookArgs[@]}"
		do
			ARGS["${key}"]=$(jetapi backup -F getHook -D "_id=${JB4HookLists[$i]}" | grep -w ${key} | sed "s/  ${key}: //")
		done
		CMD="jetbackup5api -F manageHook -D 'action=create&name=${ARGS[name]}&position_type=${ARGS[positiontype]}&position=${ARGS[position]}&script=${ARGS[script]}&disabled=1'"
		#echo $CMD
		eval $CMD
	done
else
	printWarning
	echo "There are no hooks to migrate, moving to settings."
	echo
fi