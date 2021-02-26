#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

########### Global Variables ############
FILEPATH=$(pwd)/source/files
#JB4 Args
genArgs=("debug" "errorreporting" "workspacepath" "downloadspath" "orphansttl" "logsttl" "manuallybackupretain" "manuallybackupttl")

#JB5 Args
#jb4WorkPath="/usr/local/jetapps/usr/jetbackup/workspace"
#jb4DLPath="/usr/local/jetapps/usr/jetbackup/downloads"

########### Gathering General Settings ############

jetapi backup -F getSettingsGeneral > ${FILEPATH}/settings

echo "Gathering General Settings configurations"
declare -A ARGS

for key in "${genArgs[@]}"
do
  VAL=`sed -n '/data:/,$p' < ${FILEPATH}/settings | grep -w "${key}:" | awk '{print $2}'`
  if [[ -z "${VAL}" ]] 
  then
    VAL=0
  fi
  ARGS[${key}]=${VAL}
done

########### Custom workspace/downloadspath #############
# Need to use the new jetbackup5 pathing if the user did not have custom paths.

#if [[ "${ARGS[workspacepath]}" = "${jb4WorkPath}" ]]
#then
#	ARGS[workspacepath]="/usr/local/jetapps/usr/jetbackup5/workspace"
#fi
#
#if [[ "${ARGS[downloadspath]}" = "${jb4DLPath}" ]]
#then
#	ARGS[downloadspath]="/usr/local/jetapps/usr/jetbackup5/downloads"
#fi

########### building/running the command #############

CMD="jetbackup5api -F manageSettingsGeneral -D 'debug=${ARGS[debug]}&error_reporting=${ARGS[errorreporting]}&orphan_backup_ttl=${ARGS[orphansttl]}&logs_ttl=${ARGS[logsttl]}&manually_backup_retain=${ARGS[manuallybackupretain]}&manually_backup_ttl=${ARGS[manuallybackupttl]}'"

#echo Configurations received, making changes.

eval $CMD

rm -f ${FILEPATH}/settings
