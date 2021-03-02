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
CMD=""
result=""

source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh

function setDelayType () {
	stringDelay=$1
	case "${stringDelay}" in
		'minutes')
			CMD+="&delay_type=1'"
			;;
		'hours')
			CMD+="&delay_type=2'"
			;;
		'days')
			CMD+="&delay_type=3'"
	esac
}

function createTypeData () {
	for ((j=5; j <= "${#ScheduleArgs[@]}"; j++))
	do
		if [[ "${ScheduleArgs[$j]}" =~ ^[0-9]+$ ]]
		then
			cmdindex=$(( $j - 5 ))
			CMD+="&type_data[${cmdindex}]=${ScheduleArgs[$j]}"
		else
			CMD+="'"
			break
		fi
	done
}

function createCommand () {
	local ScheduleArgs=("$@")
	
	#Checks if there is a schedule to create
	if [[ "${ScheduleArgs[1]}" = "" ]]
	then
		CMD=""
		return
	fi

	HASH=$RANDOM
	CMD="jetbackup5api -F manageSchedule -D 'action=create&name=${ScheduleArgs[1]}${HASH}"
	case "${ScheduleArgs[2]}" in
		1 )
			#echo "Hourly Schedule"
			CMD+="&type=1&type_data=${ScheduleArgs[4]}'"
			;;
		2 )
			#echo "Daily Schedule"
			CMD+="&type=2"
			createTypeData
			;;
		3 )
			#echo "Weekly Schedule"
			CMD+="&type=3&type_data=${ScheduleArgs[4]}'"
			;;
		4 )
			#echo "Monthly Schedule"
			CMD+="&type=4"
			createTypeData
			;;
		5 )
			#echo "After Backup Job Schedule"
			#Check Backup Job
			if $(checkBackupJob "${ScheduleArgs[4]}")
			then
				ID=""
				printBackupJobs
				setAfterBackupJobSchedule
				if [[ "${ID}" == "" ]]; then
					printWarning
					CMD=""
				else
					CMD+="&type=5&type_data=${ID}&delay_type=&delay_amount=${ScheduleArgs[6]}"
					setDelayType "${ScheduleArgs[5]}"
				fi
				#echo "We can migrate"
			else
				ID=""
				getExistingBackupJob "${ScheduleArgs[4]}"
				CMD+="&type=5&type_data=${ID}&delay_type=&delay_amount=${ScheduleArgs[6]}"
				setDelayType "${ScheduleArgs[5]}"
			fi
			
			;;
		6|7)
			printWarning
			echo "After Clone Job Done and After cPanel Backup Done Schedules are not supported on JetBackup 5"
			pressAnyKey
			CMD=""
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
	for scheduleIndex in "${!ScheduleIDs[@]}"
	do
		#echo "Gathering Schedule Args for id: ${ScheduleIDs[$i]}"
		gatherScheduleArgs "${ScheduleIDs[$scheduleIndex]}"
		#echo "all the args: ${ScheduleArgs[@]}"
		CMD="" #reset the command just in case
		createCommand "${ScheduleArgs[@]}"
		#echo "command = ${CMD}"
		if [[ "${CMD}" = "" ]]
		then
			echo "This Schedule ${ScheduleIDs[$scheduleIndex]} was unable to be transferred, if no other schedules, the backup job will be manual."
			sleep 2
		else
			newScheduleID=$(eval "${CMD}" | grep "_id:" | awk '{print $2}')
			Schedules+="&schedules[$scheduleIndex][_id]=${newScheduleID}&schedules[$scheduleIndex][retain]=${Retentions[$scheduleIndex]}"
		fi
	done

	#echo $Schedules #use for seeing what schedules are being added.
}

function storeSchedules () {
	backupjobid=$1
	workspace=$2
	local i=0

	readarray -t ScheduleIDs <<< "$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | sed -n '/schedules:/,$p' | grep -w "_id:" | awk '{print $2}')"

	echo "Schedules: " >> $workspace
	for i in "${!ScheduleIDs[@]}"
	do
		echo "Schedule $i: " >> $workspace
		#echo "Schedule $i: "
		#jetapi backup -F getSchedule -D "_id=${ScheduleIDs[$i]}" | sed -n '/data:/,$p'
		jetapi backup -F getSchedule -D "_id=${ScheduleIDs[$i]}" | sed -n '/_id:/,$p' | awk '/owner:/ {exit} {print}' >> $workspace
		echo "" >> $workspace
	done

}