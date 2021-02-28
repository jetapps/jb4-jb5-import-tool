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

function createAccountFilters () {
	id=$1
	NAME=$(jetapi backup -F getAccountFilter -D "_id=${id}" | grep "name" | sed 's/  name: //')
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
			newAccountFilterIds=(${newAccountFilterIds[@]} "${newID}")
			groups[$currIndex]="$((${groups[$currIndex]}+1))"
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
	echo $Filters
}

function storeAccountFilters () {
	backupjobid=$1
	workspace=$2
	local i=0
	#echo $workspace
	#echo $backupjobid
	arr=( $(jetapi backup -F getBackupJob -D "_id=${backupjobid}" | sed -e '1,/filters:/ d' | sed '/rating:/Q' | awk '{print $2}') )

	#echo "${arr[@]}" 

	for filterIndex in "${!arr[@]}"
	do
		#echo "inside for loop ${filterIndex}"
		echo "Account Filter #${filterIndex}:" >> $workspace
		#jetapi backup -F listAccountFilters | grep -B1 -A2 "${arr[$filterIndex]}" | grep -w "_id:\|name:"
		jetapi backup -F listAccountFilters | grep -B1 -A2 "${arr[$filterIndex]}" | grep -w "_id:\|name:" >> $workspace
	done
}
