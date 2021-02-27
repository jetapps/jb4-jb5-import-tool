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
Workspace=$(pwd)/source/tmp

source $(pwd)/source/ui.sh

####### Gather all Restore Condition on JB4 ##########

readarray -t ARGS <<< "$(jetapi backup -F listRestoreConditions | grep -w "_id:" | awk '{print $2}')"
echo "Gathering Restore Conditions"
printNote
echo "Restore conditions on JetBackup 5 are enabled for all restore types."
echo "Please visit https://docs.jetbackup.com/v5.1/adminpanel/settings.html#restore-conditions for more information."

####### Create Each Restore Condition on JB5 #########
for i in "${!ARGS[@]}"; do
	tmpSpace=$Workspace/rcSettings_"${ARGS[$i]}"
	touch $tmpSpace
	echo $tmpSpace
	echo "Restore Condition [$i]:"
	echo "Restore Condition [$i] to be imported:" >> $tmpSpace
	param=$(jetapi backup -F getRestoreCondition -D '_id='"${ARGS[$i]}"'' | grep "content" | sed 's/  content: //')
	echo "  condition: $param" >> $tmpSpace
	echo "  condition: $param"
	CMD="jetbackup5api -F manageRestoreCondition -D 'action=create&condition=${param}'"
	echo $CMD >> $tmpSpace
done