#!/bin/bash
###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

############## GLOBAL VARIABLES ##################
BOOLEAN=("Yes" "No")
FILEPATH=$(pwd)/source/files
snapARGS=("backup" "maxperaccount" "ttl")

source $(pwd)/source/functions.sh

readarray -t currentBackupJobIds <<< "$(jetbackup5api -F listBackupJobs | grep -w "_id:" | awk '{print $2}')"
readarray -t currentBackupJobNames <<< "$(jetbackup5api -F listBackupJobs | grep -B1 "destination" | grep name | sed 's/      name: //')"

############# Helper Functions ###############
function printBackupJobs () {
	echo Please select a Backup Job installed on JetBackup 5:
	for j in "${!currentBackupJobNames[@]}"
	do
	printf "Destination #${j}: %s\n" "${currentBackupJobNames[j]}"
	done
}

function setBackupJob () {

	while :;
	do
		read -p "Enter the number of the Backup Job you would like to use: " ID
		[[ $ID =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
		if (( $ID >= 0 && $ID < "${#currentBackupJobIds[@]}" )); then
    		echo "Using BackupJob ${currentBackupJobNames[$ID]}"
    		BOD="&backup=${currentBackupJobIds[$ID]}"
    		break
  		else
    		echo "number out of range, try again"
  		fi
	done
}

jetapi backup -F getSettingsSnapshots > ${FILEPATH}/settings
####### Get Snapshot Settings #########
printf "Gathering Snapshot Settings"
declare -A ARGS

for key in "${snapARGS[@]}"
do
  VAL=`sed -n '/data:/,$p' < ${FILEPATH}/settings | grep -w "${key}:" | awk '{print $2}'`
  if [[ -z "${VAL}" ]] 
  then
    VAL=0
  fi
  ARGS[${key}]=${VAL}
done

####### Check if snapshots were disabled ###########
BOD=""
if [[ "${ARGS[backup]}" = 0 ]]
then
	read -p "Snapshots were disabled, would you like to enable Backup on Demand with a configured Backup Job? (Yes/No) " INPUT
	if $(checkInput "$INPUT")
	then
		printBackupJobs
		setBackupJob
	else
		printWarning
		echo "Backup on Demand will not be configured. Please enable manually at Settings -> Backup on Demand."
	fi
else
	if $(checkBackupJob "${ARGS[backup]}")
	then
		echo "The Backup Job you had configured before does not exist on JetBackup 5."
		read -p "Would you like to select a different backup job? (Yes/No) " INPUT
		if [[ "${INPUT}" = "Yes" ]]
		then
			printBackupJobs
			setBackupJob 
		else
			printWarning
			echo "Backup on Demand will not be configured. Please enable manually at Settings -> Backup on Demand."
		fi
		
	else
		read -p "Would you like to use the same Backup Job for Backup on Demand? (Yes/No) " INPUT
		if $(checkInput "$INPUT")
		then
			ID=""
			getExistingBackupJob "${ARGS[backup]}"
			BOD="&backup=${ID}"
		else
			read -p "Would you like to select a different backup job? (Yes/No) " INPUT
			if $(checkInput "$INPUT")
			then
				printBackupJobs
				setBackupJob 
			else
				printWarning
				echo "Backup on Demand will not be configured. Please enable manually at Settings -> Backup on Demand."
			fi
		fi
	fi
fi

CMD="jetbackup5api -F manageSettingsSnapshots -D 'action=modify${BOD}&retain=${ARGS[maxperaccount]}&ttl=${ARGS[ttl]}'"
eval $CMD

