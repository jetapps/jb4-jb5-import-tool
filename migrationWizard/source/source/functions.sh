#!/bin/bash

###################################################################
#Script Name	: Migrate JB4 to JB5                                                                                             
#Description	: Script to migrate all supported configurations.                                                                                
#Args           :                                                                                           
#Author       	: Richard Ryan Marroquin                                                
#Email         	: richard@jetapps.com                                        
###################################################################

############# Global Variables ################
PROMPTS=("yes" "no" "y" "n" )
JB5Install="/usr/local/jetapps/etc/jetbackup5/dr.flag"
#source $(pwd)/source/BackupJobs/migrateBackupJobs.sh
FILEPATH=$(pwd)/source/files
Workspace=$(pwd)/source/tmp

source $(pwd)/source/ui.sh
source $(pwd)/source/BackupJobs/changeDestination.sh

#This file will be used for helper functions such as takeInput.

function safeExit() {
	echo
	read -p "Are you sure you want to exit? (Y/n) " INPUT
	if $(checkInput "$INPUT");then
		rm -f $FILEPATH/*
		rm -f $Workspace/*
		echo "Terminating script..."
		exit 0
	else
		echo "Returning to script..."
		echo "Please enter input for previous prompt "
		return
	fi
}

function pressAnyKey () {
	echo
	read -n 1 -r -p "Press any key to continue..."
	echo
}

function checkInput () {

	local input=$(echo "${1}" | awk '{print tolower($0)}')

	while [[ ! " ${PROMPTS[@]} " =~ " ${input} " ]];
	do
		read -p "Please enter a valid input (Yes or No): " input
		input=$(echo "${input}" | awk '{print tolower($0)}')
	done

	case $input in
		"yes" | "y" )
			#echo "hello"
			return 0
			;;
		"no" | "n" )
			#echo "goodbye"
			return 1
			;;
	esac

	#echo $input

}

function checkJB5Install () {

	if [ -f "${JB5Install}" ]; then
		return 0
	else
		return 1
	fi

}

function checkCurrentSupportedJB4Dest () {

	DESTINATIONS=(`jetapi backup -F listDestinations -D 'sort[type]=1' | grep -B 3 "engine_name: JetBackup" | grep -B 1 "type: Local\|type: SSH\|type: Rsync" | grep _id | awk '{print $2}'`)

	if [[ "${#DESTINATIONS[@]}" = "0" ]]
	then
  		echo You do not have any supported destinations. If you continue, no backup jobs and/or snapshot settings will be imported.
  		exit 1
	fi
	exit 0
}

function installSSHPlugin () {
	echo "Checking if SSH Plugin is Installed, installing otherwise"

	echo "$(jetbackup5api -F listPackages -D 'filter=SSH' | grep -w "_id\|installed" | awk '{print $2}')" > ${FILEPATH}/checkPlugin


	space=$(wc -l ${FILEPATH}/checkPlugin | awk '{print $1}')
	id=$(head -n 1 ${FILEPATH}/checkPlugin)

	if [ "$space" == 0 ]
	then
    	echo "SSH Package not available, make sure you have correct repo"
    	exit 1
	elif [ "$space" == 1 ]
	then
    	echo "Package not Installed: Installing..."
    	jetbackup5api -F installPlugin -D "package_id=${id}" | grep -B1 "message"
    	echo
	else
    	echo "Package already Installed: Continue"
	fi

	echo "Checking if plugin is enabled"

	disabled=$(jetbackup5api -F listPlugins -D 'find[name]=SSH' | grep -w "disabled:" | awk '{print $2}')
	IDPLUGIN=$(jetbackup5api -F listPlugins -D 'find[name]=SSH' | grep -w "_id:" | awk '{print $2}')

	if [ "$disabled" ]
	then
    	echo "Plugin is disabled: Enabling..."
    	jetbackup5api -F managePlugin -D '_id='"$IDPLUGIN"'&disabled=0' | grep -B1 "message"
    	service jetbackup5d restart > /dev/null 2>&1
    	echo
	else
    	echo "Plugin is enabled: Continue"
	fi
}

function checkNumDestinations () {
	local total=$(jetbackup5api -F listDestinations | grep total | awk '{print $2}')

	if [[ "${total}" = "0" ]]; then
		#echo "You do not have any Destinations configured on JetBackup 5."
		return 1
	else
		return 0
	fi
}

function checkNotificationEnabled () {
	IFS=',' read -r -a emailList <<< "$(jetapi backup -F getSettingsNotification | grep emailaddress | sed 's/.*: //')"

	if [[ "${#emailList[@]}" = 0 ]]; then
		echo "Notifications are not enabled, Please set emails manually."
		return 0
	else
		return 1
	fi
}

function checkBackupJob () {
	local backupjobid=$1
	jetbackup5api -F listBackupJobs | grep -w -B3 "destination" | grep name | sed 's/      name: //' > ${FILEPATH}/JB5BackupJobNames
	readarray -t JB5BackupJobNames < ${FILEPATH}/JB5BackupJobNames

	JB4BackupJobName=$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep -w -B1 "destination:" | grep name | sed 's/  name: //')
	if [[ ! "${JB5BackupJobNames[@]}" =~ "${JB4BackupJobName}" ]]
	then
		#echo "The Backup Job assigned to this schedule does not exist"
		return 1
	else
		#echo "The Backup Job assigned to this schedule exists"
		return 0
	fi
}

function getExistingBackupJob () {
	ID=$1
	name=$(jetapi backup -F getBackupJob -D "_id=${ID}" | grep -w -B1 "destination:" | grep -w -B1 "destination:" | grep name | sed 's/  name: //')
	ID=$(jetbackup5api -F listBackupJobs -D "filter=${name}" | grep -B2 "destination" | grep "_id" | awk '{print $2}')
}

function printBackupJobs () {
	readarray -t currentBackupJobNames <<< "$(jetbackup5api -F listBackupJobs | grep -B1 "destination" | grep name | sed 's/      name: //')"

	echo Please select a Backup Job installed on JetBackup 5:
	for j in "${!currentBackupJobNames[@]}"
	do
	printf "Backup Job #${j}: %s\n" "${currentBackupJobNames[j]}"
	done
}

function setBackupJob () {

	readarray -t currentBackupJobIds <<< "$(jetbackup5api -F listBackupJobs | grep -B2 "destination:" | grep _id | awk '{print $2}')"
	readarray -t currentBackupJobNames <<< "$(jetbackup5api -F listBackupJobs | grep -B1 "destination" | grep name | sed 's/      name: //')"

	while :;
	do
		if [[ "${#currentBackupJobIds[@]}" == "0" ]]; then
			echo "There are no Backup Jobs available."
			ID=""
			break
		else
			read -p "Enter the number of the Backup Job you would like to use: " ID
			[[ $ID =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
			if (( $ID >= 0 && $ID < "${#currentBackupJobIds[@]}" )); then
    			echo "Using BackupJob ${currentBackupJobNames[$ID]}"
    			ID="${currentBackupJobIds[$ID]}"
    			break
  			else
    			echo "number out of range, try again"
    		fi
  		fi
	done
}
########## Destination Helper Functions #############
function backupJobDestination () {
	local backupjobid=$1
	readarray -t currentJB5DestIds <<< "$(jetbackup5api -F listDestinations | grep -w "_id:" | awk '{print $2}')"
	readarray -t currentJB5Dest <<< "$(jetbackup5api -F listDestinations | grep -w -A 2 "_id:" | grep -w "name:" | sed 's/      name: //')"

	backupJobDest=$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep "destination_name" | sed 's/  destination_name: //')
	BackupJobName=$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep -B2 -w "destination:" | grep -w "name:" | sed 's/.*name: //')

	if [[ ! " ${currentJB5Dest[@]} " =~ " ${backupJobDest} " ]]; then
		echo
		echo "The destination you have configured for Backup Job ${BackupJobName} - ${backupjobid} is not configured on JetBackup 5."
		echo 
		read -p "Would you like to select a different destination for this Backup Job? (Yes/No) " INPUT

		if $(checkInput "$INPUT"); then
			newDest=""
			echo
			printDestinations
			echo
			setDestination
			#run the script to change the destination for the backup job.
			
		else
			echo "We are unable to create this Backup Job on JetBackup 5. Destination does not exist. Continuing..."
			continue
		fi
	else
		#echo "Assigining Destination - ${backupJobDest} to Backup Job - ${BackupJobName}"
		destID=$(jetbackup5api -F listDestinations -D "filter=${backupJobDest}" | grep _id | awk '{print $2}')
		newDest="&destination[0]=${destID}"
	fi
}
########## Account Filter Helper Functions ############
function createAccountFilters () {
	id=$1
	NAME=$(jetapi backup -F getAccountFilter -D "_id=${id}" | grep "name" | sed 's/.*name: //')
	TYPE=$(jetapi backup -F getAccountFilter -D "_id=${id}" | sed -n '/data:/,$p' | grep type | sed 's/  type: //')
	CONDITION=$(jetapi backup -F getAccountFilter -D "_id=${id}" | grep "condition" | sed 's/  condition: //')

	CMD="jetbackup5api -F manageAccountFilter -D 'action=create&type=${TYPE}&name=${NAME}&condition=${CONDITION}"

	case "${TYPE}" in
		2|4 )
			#Account filter & reseller & packages
			#echo "Account or Reseller"
			local accountList=( $(jetapi backup -F getAccountFilter -D "_id=${id}" | sed -n '/list:/,$p' | awk '{print $2}') )
			for i in "${!accountList[@]}"
			do
				exists=$(jetapi backup -F listAccounts -D "filter=${accountList[$i]}" | grep "total" | awk '{print $2}' )
				if [[ "${exists}" = "1" ]]
				then
					CMD+="&list[$i]=${accountList[$i]}"
				fi
			done
			;;
		16|32 )
			#Disk Space Filter & Inode Filter
			local USAGE=$(jetapi backup -F getAccountFilter -D "_id=${id}" | grep -w "usage:" | awk '{print $2}')
			CMD+="&usage=${USAGE}"
			;;
		64 )
			local packageList=( $(jetapi backup -F getAccountFilter -D "_id=${id}" | sed -n '/list:/,$p' | awk '{print $2}') )
			for i in "${!packageList[@]}"
			do
				exists=$(jetapi backup -F listPackages -D "filter=${packageList[$i]}" | grep "total" | awk '{print $2}' )
				if [[ "${exists}" = "1" ]]
				then
					CMD+="&list[$i]=${packageList[$i]}"
				fi
			done
			;;
		128 )
			#Characters Range Filter
			local START=$(jetapi backup -F getAccountFilter -D "_id=${id}" | grep -w "rangestart:" | awk '{print $2}')
			local END=$(jetapi backup -F getAccountFilter -D "_id=${id}" | grep -w "rangeend:" | awk '{print $2}')
			CMD+="&range_start=${START}&range_end=${END}"
			;;
	esac
	CMD+="'"
	#echo "${CMD}"
	newID=$(eval "${CMD}" | grep "group_id: " | awk '{print $2}')
	echo $newID
		#newAccountFilterIds=(${newAccountFilterIds[@]} "newID"
	#CMD="jetbackup5api -F manageAccountFilter -D ''"

}

function findID () {
	#Finds the real id of the account filter given the group id
	local groupID=$1
	oldID=$(jetapi backup -F listAccountFilters | grep -B1 "${groupID}" | grep -w "_id:" | awk '{print $2}')
	echo $oldID
}

function checkForFilter () {
	#Checks if the filter exists on JB5 already otherwise call the createFilter function.
	local jb4ID=$1
	local result=""
	NAME=$(jetapi backup -F getAccountFilter -D "_id=${jb4ID}" | grep "name" | sed 's/  name: //')
	readarray -t JB5Names <<< "$(jetbackup5api -F listAccountFilters -D "filter=${NAME}" | grep -w "name:" | sed 's/      name: //')"
	JB5GroupIDs=( $(jetbackup5api -F listAccountFilters -D "filter=${NAME}" | grep -w "group_id:" | awk '{print $2}') )

	if [[ "${#JB5Names[@]}" == "1" ]]
	then
		if [[ ! "${JB5Names[0]}" = "${NAME}" ]]
		then
			result=$(createAccountFilters "${jb4ID}")
		else
			result="${JB5GroupIDs[0]}"
		fi
	else
		for jb5name in "${!JB5Names[@]}"
		do
			if [[ "${JB5Names[$jb5name]}" == "${NAME}" ]]
			then
				result="${JB5GroupIDs[$jb5name]}"
			fi
		done
		if [[ "${result}" = "" ]]
		then
			result=$(createAccountFilters "${jb4ID}")
		fi
	fi

	echo $result
}



function getAccountFilters () {
	backupjobid=$1
	groups=()
	newAccountFilterIds=()
	arr=( $(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | sed -e '1,/filters:/ d' | sed '/rating:/Q' | awk '{print $2}' | awk '!NF{$0="1"}1') )

	#Create all of the new Account Filters on JetBackup 5 and store their ID's in newAccountFilterIds
	index=0
	for i in "${!arr[@]}"
	do
		if [[ "${arr[$i]}" = "1" ]]; then
			groups[$index]=0
			index="$(($index+1))"
		else
			currIndex="$(($index-1))"
			oldID=$(findID "${arr[$i]}")
			newID=$(checkForFilter "${oldID}")
			
			if [[ "$newID" = "" ]]; then
				printWarning
				echo "There was an issue creating an Account Filter for this Backup Job."
				echo "Please review all Backup Job Settings after script is complete."
				pressAnyKey
				continue
			else
				newAccountFilterIds=(${newAccountFilterIds[@]} "${newID}")
				groups[$currIndex]="$((${groups[$currIndex]}+1))"
			fi
		fi
	done

	#Build command portion for new Backup Job
	index=0
	for i in "${!groups[@]}"
	do
		for (( j=0; j < "${groups[$i]}"; j++))
		do
			Filters+="&filters[$i][$j]=${newAccountFilterIds[$index]}"
            index=$(($index+1))
		done
	done
	#echo $Filters
}

########## Schedules Helper Functions #############
function setDelayType () {
	stringDelay=$1
	case "${stringDelay}" in
		'minutes')
			scheduleCMD+="&delay_type=1'"
			;;
		'hours')
			scheduleCMD+="&delay_type=2'"
			;;
		'days')
			scheduleCMD+="&delay_type=3'"
	esac
}

function createTypeData () {
	for ((j=5; j <= "${#ScheduleArgs[@]}"; j++))
	do
		if [[ "${ScheduleArgs[$j]}" =~ ^[0-9]+$ ]]
		then
			cmdindex=$(( $j - 5 ))
			scheduleCMD+="&type_data[${cmdindex}]=${ScheduleArgs[$j]}"
		else
			scheduleCMD+="'"
			break
		fi
	done
}

function createCommand () {
	local ScheduleArgs=("$@")
	
	#Checks if there is a schedule to create
	if [[ "${ScheduleArgs[1]}" = "" ]]
	then
		scheduleCMD=""
		return
	fi

	HASH=$RANDOM
	scheduleCMD="jetbackup5api -F manageSchedule -D 'action=create&name=${ScheduleArgs[1]}${HASH}"
	echo "Here is the Schedule type: ${ScheduleArgs[2]}"
	case "${ScheduleArgs[2]}" in
		1 )
			#echo "Hourly Schedule"
			scheduleCMD+="&type=1&type_data=${ScheduleArgs[4]}'"
			;;
		2 )
			#echo "Daily Schedule"
			scheduleCMD+="&type=2"
			createTypeData
			;;
		3 )
			#echo "Weekly Schedule"
			scheduleCMD+="&type=3&type_data=${ScheduleArgs[4]}'"
			;;
		4 )
			#echo "Monthly Schedule"
			scheduleCMD+="&type=4"
			createTypeData
			;;
		5 )
			#echo "After Backup Job Schedule"
			#Check Backup Job
			if $(checkBackupJob "${ScheduleArgs[4]}")
			then
				ID=""
				printWarning
				echo "The Backup Job assigned to After Backup Job Schedule ${ScheduleArgs[1]} does not exist on JetBackup 5"
				echo "Please select a Backup Job from below"
				echo

				printBackupJobs
				setBackupJob
				if [[ "${ID}" == "" ]]; then
					scheduleCMD=""
				else
					scheduleCMD+="&type=5&type_data=${ID}&delay_type=&delay_amount=${ScheduleArgs[6]}"
					setDelayType "${ScheduleArgs[5]}"
				fi
				#echo "We can migrate"
			else
				ID=""
				getExistingBackupJob "${ScheduleArgs[4]}"
				scheduleCMD+="&type=5&type_data=${ID}&delay_type=&delay_amount=${ScheduleArgs[6]}"
				setDelayType "${ScheduleArgs[5]}"
			fi
			
			;;
		6|7)
			printWarning
			echo "After Clone Job Done and After cPanel Backup Done Schedules are not supported on JetBackup 5"
			pressAnyKey
			scheduleCMD=""
			;;
	esac
}

function gatherScheduleArgs () {
	id=$1
	#echo "Schedule: ${ScheduleIDs[$id]}"
	#jetapi backup -F getSchedule -D "_id=${ScheduleIDs[$id]}" | sed -n '/_id:/,$p' | awk '/owner:/ {exit} {print}' | awk '{print $2}' > ${FILEPATH}/scheduleargs
	readarray -t ScheduleArgs <<< "$(jetapi backup -F getSchedule -D "_id=$id" | sed -n '/_id:/,$p' | awk '/owner:/ {exit} {print}' | awk '{print $2}')"
}

function getSchedule () {
	backupjobid=$1

	readarray -t ScheduleIDs <<< "$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | sed -n '/schedules:/,$p' | grep -w "_id:" | awk '{print $2}')"
	readarray -t Retentions <<< "$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep retain | awk '{print $2}')"
	TIME=$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep -w "time:" | awk '{print $2}')

	Schedules="&time=${TIME}"

	#echo "All Schedule Ids : ${ScheduleIDs[@]}"
	if [[ "${ScheduleIDs[0]}" = "" ]]
	then
		echo "Backup Job is set to manual"
	else
		for scheduleIndex in "${!ScheduleIDs[@]}"
		do
			#echo "Gathering Schedule Args for id: ${ScheduleIDs[$i]}"
			echo "Checking for shcedule : ${ScheduleIDs[scheduleIndex]}"
			gatherScheduleArgs "${ScheduleIDs[$scheduleIndex]}"
			#echo "all the args: ${ScheduleArgs[@]}"
			scheduleCMD="" #reset the command just in case
			createCommand "${ScheduleArgs[@]}"
			if [[ "${scheduleCMD}" = "" ]]
			then
				echo "This Schedule ${ScheduleIDs[$scheduleIndex]} was unable to be transferred, if no other schedules, the backup job will be manual."
				sleep 2
			else
				newScheduleID=$(eval "${scheduleCMD}" | grep "_id:" | awk '{print $2}')
				Schedules+="&schedules[$scheduleIndex][_id]=${newScheduleID}&schedules[$scheduleIndex][retain]=${Retentions[$scheduleIndex]}"
			fi
		done
	fi

	#echo $Schedules #use for seeing what schedules are being added.
}

########## Snapshot Settings Helper ############
function assignBOD () {
	local backupjobid
	if $(checkBackupJob "$backupjobid")
	then
		echo "Backup Job Exists, assigning..."
		ID=""
		getExistingBackupJob "$backupjobid"
	else
		echo "The Backup Job you had configured before does not exist on JetBackup 5."
		read -p "Would you like to select a different backup job? (Yes/No) " INPUT
		if $(checkInput "$INPUT")
		then
			ID=""
			printBackupJobs
			setBackupJob 
		else
			printWarning
			echo "Backup on Demand will not be configured. Please enable manually at Settings -> Backup on Demand."
			BOD=""
			return
		fi
		
	fi
	BOD="&backup=${ID}"
}

########## Final Review Functions #############

function reviewDestinations () {
	DESTINATIONS=(`jetapi backup -F listDestinations -D 'sort[type]=1' | grep -B 3 "engine_name: JetBackup" | grep -B 1 "type: Local\|type: SSH\|type: Rsync" | grep _id | awk '{print $2}'`)
	local cmd
	printNote
	echo "Reviewing Destinations"
	#declare -a destCMDArray

	for destIdIndex in "${!DESTINATIONS[@]}"
	do
		destinationReviewFile=$Workspace/Destination_"${DESTINATIONS[$destIdIndex]}"
		if [ -f "$destinationReviewFile" ]; then
			echo
			cat $destinationReviewFile | sed 's/jetbackup5api.*//'
			cmd=$(cat $destinationReviewFile | grep "jetbackup5api")
			echo "$cmd" >> $Workspace/destinationcommands
			pressAnyKey
		fi
	done
}

function importDestination () {
	if [[ -f $Workspace/destinationcommands ]]
	then
		while IFS= read -r destinationCommand 
		do
			eval "$destinationCommand"
		done < "$Workspace/destinationcommands"
	else
		echo "No destinations to import"
	fi

}

function reviewBackupJobs () {
	BackupJobIDS=( `jetapi backup -F listBackupJobs | grep -w -B2 "destination:" | grep _id | awk '{print $2}'` )
	echo "Reviewing Backup Jobs"
	#echo "Here are all the backup job ids: ${BackupJobIDS[@]}"
	#declare -a cmdArray
	for idIndex in "${!BackupJobIDS[@]}"
	do
		backupJobReviewFile=$Workspace/BackupJob_"${BackupJobIDS[$idIndex]}"
		if [ -f "$backupJobReviewFile" ]; then
			echo
			echo "Backup Job [$idIndex]: "
		#show the data that will be transferred
			cat $backupJobReviewFile | sed 's/jetbackup5api.*//'
			pressAnyKey
		fi
	done
}

function importBackupJobs () {
	BackupJobIDS=( `jetapi backup -F listBackupJobs | grep -w -B2 "destination:" | grep _id | awk '{print $2}'` )
	for idIndex in "${!BackupJobIDS[@]}"
	do
		backupJobReviewFile=$Workspace/BackupJob_"${BackupJobIDS[$idIndex]}"
		if [ -f "$backupJobReviewFile" ]; then
			echo
			echo "Beginning Import of Backup Job ${BackupJobIDS[$idIndex]}"
			echo
			newDest=""
			backupJobDestination "${BackupJobIDS[$idIndex]}"
			Filters=""
			getAccountFilters "${BackupJobIDS[$idIndex]}"
			Schedules=""
			getSchedule "${BackupJobIDS[$idIndex]}"
			CMD=$(cat $backupJobReviewFile | grep "jetbackup5api")
			CMD+="$newDest$Filters$Schedules'"
			eval "$CMD"
		fi
	done
	service jetbackup5d restart > /dev/null 2>&1
	sleep 1

}

function reviewHooks () {
	JB4HookLists=($(jetapi backup -F listHooks | grep _id | awk '{print $2}'))

	for hookIdIndex in "${!JB4HookLists[@]}"
	do
		hookReviewFile=$Workspace/Hook_"$hookIdIndex"
		if [ -f "$hookReviewFile" ]; then
			echo
			echo "Hook [$hookIdIndex]: "
			cat $hookReviewFile | sed 's/jetbackup5api.*//'
			hookCmd=$(cat $hookReviewFile | grep "jetbackup5api")
			echo $hookCmd >> $Workspace/hookcommands
			pressAnyKey
		fi
	done
}

function importHooks () {
	if [ -f $Workspace/hookcommands ]; then
		while IFS= read -r hookCommand 
		do
			eval "$hookCommand"
		done < "$Workspace/hookcommands"
	else
		echo "No Hooks to import"
	fi
}

function reviewSettings () {
	readarray -t rcIDs <<< "$(jetapi backup -F listRestoreConditions | grep -w "_id:" | awk '{print $2}')"
	#General Settings
	if [ -f $Workspace/genSettings ]; then
		cat $Workspace/genSettings | sed 's/jetbackup5api.*//'

		cat $Workspace/perfSettings | sed 's/jetbackup5api.*//'

		for rcID in "${rcIDs[@]}"
		do
			cat $Workspace/rcSettings_"${rcID}" | sed 's/jetbackup5api.*//'
		done

		if [ -f $Workspace/snapSettings ]; then
			cat $Workspace/snapSettings | sed 's/jetbackup5api.*//'
		fi

		if [ -f $Workspace/emailSettings ]; then
			cat $Workspace/emailSettings | sed 's/jetbackup5api.*//'
		fi
	fi

}

function importSettings () {
	readarray -t rcIDs <<< "$(jetapi backup -F listRestoreConditions | grep -w "_id:" | awk '{print $2}')"
	#General Settings
	if [ -f $Workspace/genSettings ]; then
		eval "$(cat $Workspace/genSettings | grep jetbackup5api)"
		echo
		eval "$(cat $Workspace/perfSettings | grep jetbackup5api)"
		for rcID in "${rcIDs[@]}"
		do
			echo
			eval "$(cat $Workspace/rcSettings_"${rcID}" | grep jetbackup5api)"
		done
		if [ -f $Workspace/snapSettings ]; then
			echo "Checking Backup Job assigned to Snapshot for BOD"
			backup=$(cat $Workspace/snapSettings | grep "backup :" | awk '{print $3}')
			BOD=""
			assignBOD "$backup"
			snapCMD=$(cat $Workspace/snapSettings | grep jetbackup5api)
			snapCMD+="${BOD}'"
			eval "$snapCMD"
		fi
		if [ -f $Workspace/emailSettings ];
		then
			eval "$(cat $Workspace/emailSettings | grep jetbackup5api)"
		fi
	fi
}

function finalReview () {
	cmdFile="$Workspace/commands"
	touch $cmdFile
	reviewDestinations
	reviewBackupJobs
	reviewHooks
	reviewSettings
	echo

	read -p "Do you agree to the settings above? (Y/n) " INPUT
	if $(checkInput $INPUT)
	then
		importDestination
		importBackupJobs
		importHooks
		importSettings
	else
		echo "Please rerun the script to make any changes"
		echo "Refer to the manual for more information"
	fi

	#cleanup
	rm -f $FILEPATH/*
	rm -f $Workspace/*
}
