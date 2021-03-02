#!/bin/bash

###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

FILEPATH=$(pwd)/source/files
JB4ARGS=( "name" "dr" "hidden" "path" "disklimit" "rsyncbwlimit")
source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh

########### Storing Local Destination Arguments ################
#sed -n '/data:/,$p' < ${FILEPATH}/destinationData | grep -w "name:\|disabled:\|dr:" > ${FILEPATH}/DestArgs
#sed -n '/data:/,$p' < ${FILEPATH}/destinationData | grep -w "path:\|disklimit:\|rsyncbwlimit:\|hidden:" >> ${FILEPATH}/DestArgs

########## Creating an Array based on args in file #############
function createLocalDestination () {
  local workspace=$1

  echo "Gathering Local Destination Credentials"
  declare -A ARGS

  #printNote
  echo "Here are all the Settings that will be used for the Local Destination on JetBackup 5:" >> $workspace
  echo "" >> $workspace

  for key in "${JB4ARGS[@]}"
  do
    VAL=`sed -n '/data:/,$p' < ${FILEPATH}/destinationData | grep -w "${key}:" | sed "s/  ${key}: //"`
    if [[ -z "${VAL}" ]] 
    then
      VAL=0
    fi
    echo "${key} : ${VAL}" >> $workspace
    ARGS[${key}]=${VAL}
  done
  echo "disabled : 1" >> $workspace

  #printDefaultDisabled

########## building command ###############
CMD="jetbackup5api -F manageDestination -D 'action=create&type=Local&name=${ARGS[name]}&disabled=1&dr=${ARGS[dr]}&hidden=${ARGS[hidden]}&options[path]=${ARGS[path]}&disk_limit=${ARGS[disklimit]}&options[rsyncbwlimit]=${ARGS[rsyncbwlimit]}'"
echo $CMD >> $workspace
#eval $CMD
}