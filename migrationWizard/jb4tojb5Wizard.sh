#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : support@jetapps.com
###################################################################

################## Global Variables ###################

DESTPATH=$(pwd)/source/Destinations/migrateJB4Destinations.sh
BACKJOBPATH=$(pwd)/source/BackupJobs/migrateBackupJobs.sh
HOOKSPATH=$(pwd)/source/Hooks/migrateHooks.sh
genSetPATH=$(pwd)/source/Settings/migrateSettingsGeneral.sh
perfSetPATH=$(pwd)/source/Settings/migrateSettingsPerformance.sh
rcSetPath=$(pwd)/source/Settings/migrateSettingsRestoreConditions.sh
bodSetPath=$(pwd)/source/Settings/migrateSettingsSnapshots.sh
notifSetPath=$(pwd)/source/Settings/migrateSettingsNotification.sh
tempWorkspace=$(pwd)/source/tmp/jb4tojb5.txt

source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh
#######################################################

printTitle
trap safeExit SIGINT
#Check JB5 Installation
if checkJB5Install
then
	echo "Thank you for installing JetBackup 5, allow us to begin importing your supported JetBackup 4 configurations"
	pressAnyKey
else
	echo "You have not installed JetBackup 5, please finish installing JetBackup 5 and re run the script."
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
#if checkNumDestinations 
#then
	#echo
	#read -p "There are no Destinations imported to JetBackup 5. Would you like to continue without Backup Jobs? (Yes/No) " INPUT
	#if $(checkInput "$INPUT")
	#then
	#	printWarning
	#	echo "Skipping Backup Jobs Section because there were no Destinations imported to JetBackup 5."
	#else
	#	echo "Terminating script.... "
	#	exit 0
	#fi
	
#else
printBackupJobSection
echo "Here is a list of the current Backup Jobs that can be imported to JetBackup 5"
printSupportedJB4BackupJobs
#printUnsupportedJB4BackupJobs

read -p "Would you like to migrate your Supported Backup Jobs? (Yes/No): " INPUT
if $(checkInput "$INPUT")
then
	/bin/bash ${BACKJOBPATH}
else
	echo
	echo "Moving to Hooks."
fi
#fi

# Migrating Hooks
printHooksSection
read -p "Would you like to migrate your configured Hooks? (Yes/No): " INPUT
if $(checkInput "$INPUT")
then
	echo hello
	#/bin/bash ${HOOKSPATH}
#else
#	echo
#	echo Moving to Settings.
fi

# Migrating Settings
printSettingsSection
read -p "Would you like to migrate your settings? (Yes/No): " INPUT
if $(checkInput "$INPUT")
then
	echo "Migrating General Settings"
	#/bin/bash ${genSetPATH}

	echo "Migrating Performance Settings"
	#/bin/bash ${perfSetPATH}

	echo "Migrating Restore Conditions"
	#/bin/bash ${rcSetPath}

	echo "Migrating Snapshots Settings"
	#/bin/bash ${bodSetPath}

	if checkNotificationEnabled
	then
		echo "There are no notification settings configured in JetBackup 4."
		echo "Be sure to check out the new Notifications Plugins on JetBackup 5."
	else
		echo "Migrating Notification Settings"
		#/bin/bash ${notifSetPath}
	fi
fi

finalReview

echo "You have completed the upgrade, please review all configurations that were transferred and use the Upgrade Guide to review configurations that were not imported."



