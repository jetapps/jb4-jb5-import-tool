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
BOOLEAN=("Yes" "No")
LOCALCREATE=$(pwd)/source/Destinations/createLocalDest.sh
SSHCREATE=$(pwd)/source/Destinations/createSSHDest.sh


source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh

source $(pwd)/source/Destinations/createLocalDest.sh
source $(pwd)/source/Destinations/createSSHDest.sh
##################################################

#echo "Storing the supported destinations IDs"
DESTINATIONS=(`jetapi backup -F listDestinations -D 'sort[type]=1' | grep -B 3 "engine_name: JetBackup" | grep -B 1 "type: Local\|type: SSH\|type: Rsync" | grep _id | awk '{print $2}'`)

############### Iterate through all supported destinations and ask if they should be ported ###############
for id in ${DESTINATIONS[@]}
do
  echo
  #echo "Retrieving Destination Configuration of Destination: $id"
  jetapi backup -F getDestination -D "_id=${id}" > ${FILEPATH}/destinationData
  NAME=$(grep -w "name:" ${FILEPATH}/destinationData | sed 's/  name: //')
  JB5Exists=$(jetbackup5api -F listDestinations -D "filter=$NAME" | grep -A15 options | grep total | awk '{print $2}')

  if [[ "${JB5Exists}" = "1" ]]; then
    echo "Destination \"${NAME}\" already exists on JetBackup 5, moving to next destination"
    continue
  fi

  destinationSpace="$(pwd)/source/tmp/Destination_$id"
  touch $destinationSpace
  
  # Creating  a Local Destination
  if grep -wq "type: Local" ${FILEPATH}/destinationData
  then
    echo "Storing configuration of Local Destination: ${NAME} - ${id}"
    #echo
    #read -p "Would you like to create this Local Destination on JB5 (Yes/No): " INPUT
    #if $(checkInput "$INPUT")
    #then
      #echo "Making Local Destination on JB5: "
      createLocalDestination "${destinationSpace}"
      #if [[ "$?" == "1" ]];then #User Agreed to settings
        #printNote
        #echo "Please edit the Local Destination through the JetBackup 5 Interface to update settings as needed."
        #echo
        #pressAnyKey
      #else
        #pressAnyKey
      #fi

    #else
      #echo "Skipping to next Destination"
    #fi

  else # Creating an SSH Destination
    echo "Storing configuration of SSH/Rsync Destination: ${NAME} - ${id}"
    #read -p "Would you like to create this SSH/Rsync Destination on JB5 using the same credentials? (Yes/No): " INPUT
    #if $(checkInput "$INPUT")
    #then
    #echo "Making SSH Destination on JB5"
    createSSHDestination "${destinationSpace}"
      #if [[ "$?" == "1" ]];then #User Agreed to setting
        #echo "Please edit the SSH Destination through the JetBackup 5 interface to update settings as needed."
        #echo
        #pressAnyKey
      #else
        #pressAnyKey
      #fi
    #else
      #echo "Skipping to next Destination"
    #fi
  fi 
done

#countNonMigrated=$(jetapi backup -F listDestinations | grep -c "type: GoogleDrive\|type: SFTP\|type: FTP\|type: Dropbox\|type: AmazonS3\|type: Backblaze")
#countHope=$(jetapi backup -F listDestinations | grep -c "type: SFTP\|type: FTP")

#if [[ "$countNonMigrated" -gt 0 ]]; then
  #printWarning
  #printUnSupportedJB4Destinations
  #printNote
  #echo "For more information about JetBackup 5 Supported Destination Types please visit our Destination Overview: https://docs.jetbackup.com/v5.1/adminpanel/Destinations/destination.html"

  #if [[ "$countHope" -gt 0 ]]; then
    #echo "JetBackup 5 does not support FTP/SFTP protocols. Please review your destination as it may support the SSH protocol and be configured as an SSH destination in JetBackup 5"
  #fi
#fi
pressAnyKey
