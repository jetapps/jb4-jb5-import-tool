#!/bin/bash

###################################################################
#Script Name	: Migrate JB4 to JB5                                                                                             
#Description	: Script to migrate all supported configurations.                                                                                
#Args           :                                                                                           
#Author       	: Richard Ryan Marroquin                                                
#Email         	: support@jetapps.com                                        
###################################################################

########## Global Variables ############
FILEPATH=$(pwd)/source/files
#chDestPath=$(pwd)/source/BackupJobs/changeDestination.sh
BOOLEAN=("Yes" "No")

source $(pwd)/source/functions.sh
#source $(pwd)/source/BackupJobs/changeDestination.sh
source $(pwd)/source/BackupJobs/accountFilters.sh
source $(pwd)/source/BackupJobs/excludeLists.sh
source $(pwd)/source/BackupJobs/changeSchedule.sh

########## Helper Functions ################
function getBackupJobType () {
	local backupjobid=$1
	currType=$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep -w "backuptypes" | awk '{print $2}')
	currStruct=$(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | grep -w "flag:" | awk '{print $2}')

	
	if [[ "${currType}" = "512" ]] #Check if type Replicate
	then
		CONFIG=""
	elif [[ "${currType}" = "384" ]] #Check if type Directories
	then
		IncludeList=""
		createIncludeList "${backupjobid}"
		CONFIG="&type=2&contains=3&structure=${currStruct}${IncludeList}"
	elif [[ "${currType}" = "127" ]] #Check if Full Account
	then
		printNote
		echo "JetBackup 5 Now allows you to backup two new items seperately: Database Users and FTP Accounts"
		echo "For More information, please visit: https://docs.jetbackup.com/v5.1/adminpanel/backupJobs.html#backup-type"
		echo "These items will automatically be included in Full Account Backups. You can change these settings from within the JetBackup 5 Backup Jobs Interface."
		echo
		#automatically include Database Users and FTP Accounts
		currTypeBin=$(echo "obase=2; ${currType}" | bc | rev) #Convert type value to binary
		currTypeBin+=11
		CONTAINS=$(echo "$((2#$currTypeBin))")
		CONFIG="&type=1&contains=${CONTAINS}&structure=${currStruct}"

	else
		currTypeBin=$(echo "obase=2; ${currType}" | bc | rev) #Convert type value to binary
		printNote
		echo "JetBackup 5 Now allows you to backup two new items seperately: Database Users and FTP Accounts"
		echo "For More information, please visit: https://docs.jetbackup.com/v5.1/adminpanel/backupJobs.html#backup-type"
		echo

		#if [[ "${currTypeBin:2:1}" = "1" ]] #Check Database configuration
		#then
		read -p "Would you like to backup Database Users as well? (Yes/No): " INPUT
		if $(checkInput "$INPUT")
		then
			currTypeBin+=1
		else
			currTypeBin+=0
		fi
		#else
		#fi

		read -p "Would you like to backup FTP Accounts as well? (Yes/No): " INPUT
		if $(checkInput "$INPUT")
		then
			currTypeBin+=1
		else
			currTypeBin+=0
		fi

		currTypeBin=$(echo $currTypeBin | rev)
		CONTAINS=$(echo "$((2#$currTypeBin))")
		CONFIG="&type=1&contains=${CONTAINS}&structure=${currStruct}"

	fi
}
# Storing a list of all the backup jobs currently configured
jetapi backup -F listBackupJobs > ${FILEPATH}/JB4BackupJobs

#echo Here are all the Backup Jobs Currently configured:
#cat ${FILEPATH}/JB4BackupJobs | grep -w -B2 "destination:" | grep -B 1 name

echo
#printf "Printing out all Backup Job IDs\n"
BackupJobIDS=( `cat ${FILEPATH}/JB4BackupJobs | grep -w -B2 "destination:" | grep _id | awk '{print $2}'` )

for i in "${!BackupJobIDS[@]}"
do
	BackupJobName=$(jetapi backup -F getBackupJob -D "_id=${BackupJobIDS[$i]}" | grep -B1 "destination:" | grep -w "name:" | sed 's/  name: //')

	exists=$(jetbackup5api -F listBackupJobs -D "filter=${BackupJobName}" | grep total | awk '{print $2}')

	if [[ "$exists" != "0" ]]; then
		echo "Backup Job \"${BackupJobName}\" already exists on JetBackup 5, moving to next."
		continue
	fi

	tmpSpace="$(pwd)/source/tmp/BackupJob_${BackupJobIDS[$i]]}"
	touch $tmpSpace

	echo "Name: ${BackupJobName}" >> $tmpSpace
	#read -p "Would you like to configure ${BackupJobName} on JB5? (Yes/No): " INPUT
	
	#if $(checkInput "$INPUT");then
	echo "Collecting data for Backup Job: ${BackupJobName}"
	sleep 1

		#Check the Configuration
	echo
	echo "Storing Backup Job Configuration"
	CONFIG=""
	getBackupJobType "${BackupJobIDS[$i]}"

	if [[ "${CONFIG}" = "" ]]
	then
		printWarning
		echo "Cannot migrate '${BackupJobName}'- Replicate Backup Jobs are not supported on JetBackup 5"
		echo "Please refer to the guide or visit our documentation for more information: https://docs.jetbackup.com/v5.1/adminpanel/backupJobs.html"
		pressAnyKey
		continue
	fi

	#Check the Destinations
	echo
	echo "Storing Backup Job Destination"
	backupJobDest=$(jetapi backup -F getBackupJob -D "_id=${BackupJobIDS[$i]}" | grep "destination_name" | sed 's/  destination_name: //')
	echo "Destintation: ${backupJobDest}" >> $tmpSpace

	#if [[ ! " ${currentJB5Dest[@]} " =~ " ${backupJobDest} " ]]; then
	#	echo
	#	echo "The destination you have configured for Backup Job ${BackupJobName} - ${BackupJobIDS[$i]} is not configured on JetBackup 5."
	#	echo 
	#	read -p "Would you like to select a different destination for this Backup Job? (Yes/No) " INPUT
#
#		if $(checkInput "$INPUT"); then
#			newDest=""
#			echo
#			printDestinations
#			echo
#			setDestination
#			destid=$(echo $newDest | sed 's/.*=//')
#			jetbackup5api -F getDestination -D "_id=${destid}" | sed -n '/data:/,$p'>> $tmpSpace
#			#run the script to change the destination for the backup job.
#			
#		else
#			echo "We are unable to create this Backup Job on JetBackup 5. Destination does not exist. Continuing..."
#			continue
#		fi
#	else
#		#echo "Assigining Destination - ${backupJobDest} to Backup Job - ${BackupJobName}"
#		destID=$(jetbackup5api -F listDestinations -D "filter=${backupJobDest}" | grep _id | awk '{print $2}')
#		newDest="&destination[0]=${destID}"
#		jetbackup5api -F getDestination -D "_id=${destID}" | sed -n '/data:/,$p'>> $tmpSpace
#	fi

	#Check Account Filters
	echo
	echo "Storing Account Filters"
	currType=$(jetapi backup -F getBackupJob -D "_id=${BackupJobIDS[$i]}" | grep -w "backuptypes" | awk '{print $2}')
	#echo "Here is the current Backup Job Id: ${BackupJobIDS[$i]} and here is the current type: ${currType}"
	if [[ "${currType}" -ne "384" ]]; then
		#read -p "Would you like to use the same Account Filter(s) as before? (Yes/No) " INPUT
		#if $(checkInput "$INPUT")
		#then
		#echo "${BackupJobIDS[$i]}"
		#getAccountFilters "${BackupJobIDS[$i]}"
		storeAccountFilters "${BackupJobIDS[$i]}" "${tmpSpace}"
		#Filters=$(getAccountFilters "${BackupJobIDS[$i]}")
		#echo $Filters
		#echo "${BackupJobIDS[$i]}"
	else
		#echo "This backup job will have no Account Filters, please review before enabling."
		Filters=""
		#fi
	fi

	#Check Exclude Lists
	#read -p "Would you like to use the same Exclude List as before? (Yes/No) " INPUT
	#if $(checkInput "$INPUT")
	#then
	echo
	echo "Storing Exclude Lists"
	#echo "${BackupJobIDS[$i]}"
	ExcludeList=""
	#echo "${BackupJobIDS[$i]}"
	createExcludeList "${BackupJobIDS[$i]}" "${tmpSpace}"
	#echo "$ExcludeList"
	#echo "${BackupJobIDS[$i]}"
	#else
	#	echo "This backup job will have no Exclude Filters, please review before enabling."
	#	ExcludeList=""
	#fi

	#Check the Schedules
	#read -p "Would you like to use the same schedule(s) as before?" INPUT
	#if $(checkInput "$INPUT")
	#then
	echo
	echo "Storing Schedules"
	storeSchedules "${BackupJobIDS[$i]}" "${tmpSpace}"
	echo
	#else
	#echo "This backup job will be configured as a manual backup job, please set a schedule in the JB5 interface."
	#Schedules=""
	#fi

	#Run the command to create the Backup Job
	CMD="jetbackup5api -F manageBackupJob -D 'action=create&name=${BackupJobName}&disabled=1${CONFIG}${ExcludeList}"
	echo $CMD >> $tmpSpace
	#echo $CMD > $(pwd)/source/tmp/BackupJob_"${BackupJobName}"
	#eval "$CMD"
	CMD="" #reset the command

	#fi
done