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

####### Gather all Restore Condition on JB4 ##########

readarray -t ARGS <<< "$(jetapi backup -F listRestoreConditions | grep -w "_id:" | awk '{print $2}')"

####### Create Each Restore Condition on JB5 #########
for i in "${!ARGS[@]}"; do
	param=$(jetapi backup -F getRestoreCondition -D '_id='"${ARGS[$i]}"'' | grep "content" | sed 's/  content: //')
	CMD="jetbackup5api -F manageRestoreCondition -D 'action=create&condition=${param}'"
	eval ${CMD}
done