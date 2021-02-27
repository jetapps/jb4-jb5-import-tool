#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

###### Global Variables ######
FILEPATH=$(pwd)/source/files
Workspace=$(pwd)/source/tmp

source $(pwd)/source/functions.sh

IFS=',' read -r -a emailList <<< "$(jetapi backup -F getSettingsNotification | grep emailaddress | sed 's/.*: //')"
##############################

####### Helper Functions ########

function generateAlerts () {
	alerts=$(jetapi backup -F getSettingsNotification | grep -w "alerts:" | awk '{print $2}')
	alertsBin=$(echo "obase=2; ${alerts}" | bc | sed 's/[0]*$//g')

	alerts=$(echo "$((2#$alertsBin))") #sets new alerts value
}

function generateRecipients () {
	local recipients="${emailList[0]}"
	for ((i=1; i < "${#emailList[@]}"; i++))
	do
		recipients+=",${emailList[$i]}"
	done

	echo $recipients
}

function setupEmailServer () {
	
	generateAlerts
	recipients=$(generateRecipients)
	echo "  level : ${alerts}" >> $tmpSpace
	echo "  recipients : ${recipients}" >> $tmpSpace

	local CMD="jetbackup5api -F manageNotificationIntegration -D 'type=Email&level=${alerts}&options[recipients]=${recipients}&frequency[1]=1&frequency[2]=1&frequency[4]=1'"
	echo $CMD >> $tmpSpace

}

function setupSMTPServer () {
	generateAlerts
	recipients=$(generateRecipients)
	echo "  level : ${alerts}" >> $tmpSpace
	echo "  recipients : ${recipients}" >> $tmpSpace

	local keys=("smtp_from" "smtp_host"  "smtp_port" "smtp_username" "smtp_password" "smtp_secure" "smtp_verifyssl" "smtp_timeout")
	local jb4Args=( $(jetapi backup -F getSettingsNotification | grep "smtp\|verifyssl\|timeout" | awk '{print $2}') )

	CMD="jetbackup5api -F manageNotificationIntegration -D 'type=Email&level=${alerts}"
	for index in "${!jb4Args[@]}"
	do
		CMD+="&options[${keys[$index]}]=${jb4Args[$index]}"
		echo "  ${keys[$index]} : ${jb4Args[$index]}}" >> $tmpSpace
	done
	CMD+="&options[recipients]=${recipients}&frequency[1]=1&frequency[2]=1&frequency[4]=1'"
	echo $CMD >> $tmpSpace
}

########## Main #################

#check if notifications are set on JetBackup 4.

emailServer=$(jetapi backup -F getSettingsNotification | grep emailserver | awk '{print $2}')
tmpSpace=$Workspace/emailSettings
touch $tmpSpace

echo "Notification Settings to be imported: " >> $tmpSpace

if [[ "$emailServer" = "1" ]]
then
	setupEmailServer
else
	setupSMTPServer
fi 

