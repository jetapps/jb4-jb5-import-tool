#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

function printTitle () {
	echo -e "\n${GREEN}"
	echo "   ###############################################"
	echo "   #   _ ____ ___ ___  ____ ____ _  _ _  _ ___   #"
	echo "   #   | |___  |  |__] |__| |    |_/  |  | |__]  #"
	echo "   #  _| |___  |  |__] |  | |___ | \_ |__| |     #"
	echo "   #    _  _ _ ____ ____ ____ ___ _ ____ _  _    #"
	echo "   #    |\/| | | __ |__/ |__|  |  | |  | |\ |    #"
	echo "   #    |  | | |__] |  \ |  |  |  | |__| | \|    #"
	echo "   #              ___ ____ ____ _                #"
	echo "   #               |  |  | |  | |                #"
	echo "   #               |  |__| |__| |___             #"
	echo "   #                                             #"
	echo "   ###############################################"
	echo -e "\n${NC}"
}

function printNote () {
	echo -e "\n"
	echo "   ############################"
	echo "   #  _  _         _          #"
 	echo "   # | \| |  ___  | |_   ___  #"
	echo "   # | .' | / _ \ |  _| / -_) #"
 	echo "   # |_|\_| \___/  \__| \___| #"
 	echo "   #                          #"
 	echo "   ############################"
 	echo -e "\n"                     
}

function printWarning () {
	echo -e "\n${YELLOW}"
        echo "   #############################################"
        echo "   # __      __                 _              #"
        echo "   # \ \    / /__ _  _ _  _ _  (_) _ _   __ _  #"
        echo "   #  \ \/\/ // _\` || '_|| ' \ | || ' \ / _\` | #"
        echo "   #   \_/\_/ \__,_||_|  |_||_||_||_||_|\__, | #"
        echo "   #                                    |___/  #"
        echo "   #############################################"	
	echo -e "\n${NC}"                                                              
}

function printDestinationSection () {
	echo -e "\n"
	echo "   #######################################################"
	echo "   # ___  ____ ____ ___ _ _  _ ____ ___ _ ____ _  _ ____ #"
	echo "   # |  \ |___ [__   |  | |\ | |__|  |  | |  | |\ | [__  #"
	echo "   # |__/ |___ ___]  |  | | \| |  |  |  | |__| | \| ___] #"
	echo "   #                                                     #"
	echo "   #######################################################"
	echo -e "\n"
}

function printBackupJobSection () {
	echo -e "\n"
	echo "   #####################################################"
	echo "   # ___  ____ ____ _  _ _  _ ___     _ ____ ___  ____ #"
	echo "   # |__] |__| |    |_/  |  | |__]    | |  | |__] [__  #"
	echo "   # |__] |  | |___ | \_ |__| |      _| |__| |__] ___] #"
	echo "   #                                                   #"
	echo "   #####################################################"
	echo -e "\n"
}

function printHooksSection () {
	echo -e "\n"
	echo "   ############################"
	echo "   # _  _ ____ ____ _  _ ____ #"
	echo "   # |__| |  | |  | |_/  [__  #"
	echo "   # |  | |__| |__| | \_ ___] #"
	echo "   #                          #"
	echo "   ############################"
	echo -e "\n"
}

function printSettingsSection () {
	echo -e "\n"
	echo "   ######################################"
	echo "   # ____ ____ ___ ___ _ _  _ ____ ____ #"
	echo "   # [__  |___  |   |  | |\ | | __ [__  #"
	echo "   # ___] |___  |   |  | | \| |__] ___] #"
	echo "   #                                    #"
	echo "   ######################################"
	echo -e "\n"
}

function printSupportedJB4Destinations () {
	echo
	jetapi backup -F listDestinations -D 'sort[type]=1' | grep -B 3 "engine_name: JetBackup" | grep -C 1 "type: Local\|type: SSH\|type: Rsync}"
	echo
}

function printUnSupportedJB4Destinations () {
	countNonMigrated=$(jetapi backup -F listDestinations | grep -c "type: GoogleDrive\|type: SFTP\|type: FTP\|type: Dropbox\|type: AmazonS3\|type: Backblaze")
	countHope=$(jetapi backup -F listDestinations | grep -c "type: SFTP\|type: FTP")

	if [[ "$countNonMigrated" -gt 0 ]]; then
  		printWarning
  		echo
  		echo -e "Here are the destinations that ${YELLOW}CANNOT${NC} be imported to JetBackup 5"
  		echo
		jetapi backup -F listDestinations | grep -C1 "type: GoogleDrive\|type: SFTP\|type: FTP\|type: Dropbox\|AmazonS3\|Backblaze"
		echo
  		echo "For more information about JetBackup 5 Supported Destination Types please visit our Destination Overview: https://docs.jetbackup.com/v5.1/adminpanel/Destinations/destination.html"

  		if [[ "$countHope" -gt 0 ]]; then
    		echo "JetBackup 5 does not support FTP/SFTP protocols. Please review your destination as it may support the SSH protocol and be configured as an SSH destination in JetBackup 5"
  		fi
	fi
}

function printSupportedJB4BackupJobs () {
	echo
	jetapi backup -F listBackupJobs | grep -w -B2 "destination:" | grep -B1 name
	echo
}

function printUnSupportedJB4BackupJobs () {
	printWarning
	echo
	jetapi backup -F listBackupJobs | grep -B5 "backuptype: 512" | grep -B1 name
	echo
	echo "JetBackup 5 does not support Replicate/Clone Jobs"
	echo "GDPR Jobs can be configured manually with Encrypted Backup Jobs, please visit https://docs.jetbackup.com/v5.1/adminpanel/backupJobs.html#encrypted-backups for more information"

}

function printDefaultDisabledDestination () {
	echo
	echo -e "Please note that Destinations will be ${YELLOW}DISABLED${NC} by default."
	echo "You may navigate to Destination Settings to enable your destination after reviewing its configuration within the JetBackup Interface"
	echo
}

function printDefaultDisabledBackupJob () {
	echo
	echo -e "Please note that Backup Jobs will be ${YELLOW}DISABLED${NC} by default."
	echo "You may navigate to Backup Jobs Settings to enable your Backup Job after reviewing its configuration within the JetBackup Interface"
	echo
}


