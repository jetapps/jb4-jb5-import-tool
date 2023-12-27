#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : support@jetapps.com
###################################################################

################## Global Variables ###################

DESTPATH=$(pwd)/source/Destinations/importJB4Destinations.sh
BACKJOBPATH=$(pwd)/source/BackupJobs/importBackupJobs.sh
HOOKSPATH=$(pwd)/source/Hooks/importHooks.sh
genSetPATH=$(pwd)/source/Settings/importSettingsGeneral.sh
perfSetPATH=$(pwd)/source/Settings/importSettingsPerformance.sh
rcSetPath=$(pwd)/source/Settings/importSettingsRestoreConditions.sh
bodSetPath=$(pwd)/source/Settings/importSettingsSnapshots.sh
notifSetPath=$(pwd)/source/Settings/importSettingsNotification.sh
tempWorkspace=$(pwd)/source/tmp/jb4tojb5.txt
tempFiles=$(pwd)/source/files/File.txt

source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh
#######################################################

printTitle
trap safeExit SIGINT
#Check JB4 Installation
if checkJB4Install
then
	echo ""
else
	echo "JetBackup 4 is not installed"
	exit 123
fi

#Check JB5 Installation
if checkJB5Install
then
	echo "Thank you for installing JetBackup 5, allow us to begin importing your supported JetBackup 4 configurations"
	pressAnyKey
else
	echo "JetBackup 5 v5.2.11 is not installed. Please install JetBackup 5 v5.2.11 by using the following command, complete the initial setup, and then re run the script."
	echo ""
	echo "yum install jetbackup5-cpanel-5.2.11 --disablerepo=* --enablerepo=jetapps,jetapps-stable" 
	exit 1
fi

#Initializing Temp Folder

printf "\nInitializing temporary workspace..."

if [[ ! -f $tempWorkspace ]]
then
	if [[ ! -d $(pwd)/source/tmp ]]
	then
		mkdir $(pwd)/source/tmp
	fi

	touch $tempWorkspace
fi

if [[ ! -f $tempFiles ]]
then
	if [[ ! -d $(pwd)/source/files ]]
	then
		mkdir $(pwd)/source/files
	fi
	touch $tempFiles
fi

printf "DONE\n\n";

# Migrating Destinations
printDestinationSection
$(checkCurrentSupportedJB4Dest)
if [[ $? -eq 1 ]]
then
	echo "There are no destinations that can be imported to JetBackup 5"
	read -p "Would you like to continue to import Hooks and Settings?" INPUT
	if $(checkInput "$INPUT"); then
		echo "Jumping to Hooks"
	else
		echo "Terminating script..."
		exit 1
	fi
else
	echo "Here is a list of current Destinations that can be imported to JetBackup 5"
	printSupportedJB4Destinations
	printUnSupportedJB4Destinations
	printNote
	printDefaultDisabledDestination
	echo "If choose to not import your destinations, the backup jobs that utilize these destinations will not be imported."
	read -p "Would you like to import your destinations? (Yes/No): " INPUT

	if $(checkInput "$INPUT")
	then
		/bin/bash ${DESTPATH}
	else
		echo Moving to Backup Jobs.
	fi
fi

# Migrating Backup Jobs
if [ $(checkInput "$INPUT") -o $(checkNumDestinations) ] #checks if user accepted to migrate destination
then
	printBackupJobSection
	echo "Here is a list of the current Backup Jobs that can be imported to JetBackup 5"
	printSupportedJB4BackupJobs

	read -p "Would you like to migrate your Supported Backup Jobs? (Yes/No): " INPUT
	if $(checkInput "$INPUT")
	then
		/bin/bash ${BACKJOBPATH}
	else
		echo
		echo "Moving to Hooks."
	fi
else
	printWarning
	echo "Skipping Backup Jobs Section because there were no Destinations imported to JetBackup 5."
fi

# Migrating Hooks
printHooksSection
read -p "Would you like to migrate your configured Hooks? (Yes/No): " INPUT
if $(checkInput "$INPUT")
then
	/bin/bash ${HOOKSPATH}
else
	echo
	echo Moving to Settings.
fi

# Migrating Settings
printSettingsSection
read -p "Would you like to migrate your settings? (Yes/No): " INPUT
if $(checkInput "$INPUT")
then
	echo 
	/bin/bash ${genSetPATH}

	echo 
	/bin/bash ${perfSetPATH}

	echo
	/bin/bash ${rcSetPath}

	echo
	enabled=$(jetapi backup -F getSettingsSnapshots | grep backup | awk '{print $2}')
	if [[ "$enabled" = "" ]]
	then
		echo "Snapshots were not enabled on JetBackup 4."
		echo "Be sure to check out the new Backup on Demand Feature in JetBackup 5"
		echo "For more information, please visit: https://docs.jetbackup.com/v5.1/adminpanel/settings.html#backup-on-demand"
	else
		/bin/bash ${bodSetPath}
	fi

	if checkNotificationEnabled
	then
		echo "There are no notification settings configured in JetBackup 4."
		echo "Be sure to check out the new Notifications Plugins on JetBackup 5."
	else
		echo "Migrating Notification Settings"
		/bin/bash ${notifSetPath}
	fi
fi

finalReview

echo "You have completed the upgrade, please review all configurations that were transferred and use the Upgrade Guide to review configurations that were not imported."
