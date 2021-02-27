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
Workspace=$(pwd)/source/tmp
#JB4 Args
genArgs=("debug" "errorreporting" "workspacepath" "downloadspath" "orphansttl" "logsttl" "manuallybackupretain" "manuallybackupttl")

#JB5 Args
#jb4WorkPath="/usr/local/jetapps/usr/jetbackup/workspace"
#jb4DLPath="/usr/local/jetapps/usr/jetbackup/downloads"

########### Gathering General Settings ############

jetapi backup -F getSettingsGeneral > ${FILEPATH}/settings
DTTL=$(jetapi backup -F getSettingsPerformance | grep -w "downloadsttl:" | awk '{print $2}')

echo "Gathering General Settings configurations"
declare -A ARGS
tmpSpace=$Workspace/genSettings
touch $tmpSpace

echo "General Settings to be imported: " >> $tmpSpace

for key in "${genArgs[@]}"
do
  VAL=`sed -n '/data:/,$p' < ${FILEPATH}/settings | grep -w "${key}:" | awk '{print $2}'`
  if [[ -z "${VAL}" ]] 
  then
    VAL=0
  fi
  ARGS[${key}]=${VAL}
  echo "  $key : ${ARGS[$key]}" >> $tmpSpace
  echo "  $key : ${ARGS[$key]}"
done
echo "  downloadsttl : $DTTL"
echo "  downloadsttl : $DTTL" >> $tmpSpace


########### building/running the command #############

CMD="jetbackup5api -F manageSettingsGeneral -D 'downloads_ttl=$DTTL&debug=${ARGS[debug]}&error_reporting=${ARGS[errorreporting]}&orphan_backup_ttl=${ARGS[orphansttl]}&logs_ttl=${ARGS[logsttl]}&manually_backup_retain=${ARGS[manuallybackupretain]}&manually_backup_ttl=${ARGS[manuallybackupttl]}'"
echo "" >> $tmpSpace
echo $CMD >> $tmpSpace
#echo Configurations received, making changes.

#eval $CMD

rm -f ${FILEPATH}/settings
