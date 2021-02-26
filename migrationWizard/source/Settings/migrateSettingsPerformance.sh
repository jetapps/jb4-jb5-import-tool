#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

########### Global Variables ############
FILEPATH=$(find / -type d -name migrationWizard -print -quit)/source/files
#JB4 Args
perfArgs=("maxloadaverage" "limitdownloads" "downloadsttl" "mysqldumpmaxpacket" "mysqldumpforce" "mysqldumpopt" "mysqldumpskiplock" "dirs_queue_priority")

########### Gathering General Settings ############

jetapi backup -F getSettingsPerformance > ${FILEPATH}/settings

echo "Gathering Performance Settings configurations"
declare -A ARGS

for key in "${perfArgs[@]}"
do
  VAL=`sed -n '/data:/,$p' < ${FILEPATH}/settings | grep -w "${key}:" | awk '{print $2}'`
  if [[ -z "${VAL}" ]] 
  then
    VAL=0
  fi
  ARGS[${key}]=${VAL}
done

########## Warnings about what is not being transferred #############
#echo Please note that the following settings are not available in jetbackup5: Concurrent Queued Tasks, Concurrent Scheduled Tasks, Compress databases on backup process, Skip Bandwidth Data, 
#echo Please visit URL to see all the settings that have not been migrated.

########### building/running the command ############

#TODO Add stuff for dir_queue_prio

CMD="jetbackup5api -F manageSettingsPerformance -D 'mysqldump_max_packet=${ARGS[mysqldumpmaxpacket]}&mysqldump_force=${ARGS[mysqldumpforce]}&mysqldump_opt=${ARGS[mysqldumpopt]}&mysqldump_skip_lock=${ARGS[mysqldumpskiplock]}'"

echo Configurations received, making changes.
eval $CMD

rm -f ${FILEPATH}/settings