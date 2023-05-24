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
JB4FTPARGS=( "_id" "name" "dr" "hidden" "disklimit" "path" "host" "port" "username" "password" "timeout" "passive" "retries" "ssl" "timeout" "connections" )

FTPDESTINATIONS=(`jetapi backup -F listDestinations -D 'sort[type]=1' | grep -B 3 "engine_name: JetBackup" | grep -B 1 "type: FTP" | grep _id | awk '{print $2}'`)


source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh
##############################

###### Checking for FTP Plugin, install otherwise #######

########### Storing Local Destination Arguments ################
function createFTPDestination () {
  local workspace=$1
  installFTPPlugin
  echo "Gathering FTP Credentials"

  #printNote
  echo "Here are all the Settings that will be used for the FTP Destination on JetBackup 5:" >> $workspace
  echo "" >> $workspace
  declare -A ARGS

  for key in "${JB4FTPARGS[@]}"
  do
    VAL=`sed -n '/data:/,$p' < ${FILEPATH}/destinationData | grep -w "${key}:" | sed "s/  ${key}: //"`
    if [[ -z "${VAL}" ]] 
    then
      VAL=0
    fi
    ARGS[${key}]=${VAL}
    
    echo "${key} : ${ARGS[$key]}" >> $workspace
  done

 for ftpid in ${FTPDESTINATIONS[@]}
  do

    FTPPASSWORD=$(cat /usr/local/jetapps/etc/jetbackup/destinations/lftp/${ARGS[_id]} | grep "lftp" | sed "s/.*'[^,]*,\([^']*\)'.*/\1/")
    ARGS['ftppassword']=${FTPPASSWORD}
  done

  echo "" >> $workspace
  #printDefaultDisabled

echo "About to build the destination"

########## building command ###############
CMD="jetbackup5api -F manageDestination -D 'action=create&type=FTP&name=${ARGS[name]}&disabled=1&dr=${ARGS[dr]}&hidden=${ARGS[hidden]}&options[path]=${ARGS[path]}&disk_limit=${ARGS[disklimit]}&options[server]=${ARGS[host]}&options[port]=${ARGS[port]}&options[password]=${ARGS[ftppassword]}&options[username]=${ARGS[username]}&options[passive]=${ARGS[passive]}&options[retries]=${ARGS[retries]}&options[secure]=${ARGS[ssl]}&options[timeout]=${ARGS[timeout]}&threads=2'"
#eval $CMD
echo $CMD >> $workspace
}
