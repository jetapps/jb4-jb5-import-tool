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
JB4ARGS=( "name" "dr" "hidden" "path" "disklimit" "rsyncbwlimit" "host" "port" "username" "timeout" "rsyncpreferip" "privatekey")
JB4SSHKEY=/usr/local/jetapps/etc/jetbackup/privatekeys/root.rsa
JB5SSHKEY=/usr/local/jetapps/etc/jetbackup5/privatekeys/root.rsa

source $(pwd)/source/functions.sh
source $(pwd)/source/ui.sh
##############################

###### Checking for SSH Plugin, install otherwise #######

########### Storing Local Destination Arguments ################
function createSSHDestination () {
  local workspace=$1
  installSSHPlugin
  #echo "Gathering SSH Credentials"

  #printNote
  echo "Here are all the Settings that will be used for the SSH/Rsync.net Destination on JetBackup 5:" >> $workspace
  echo "" >> $workspace
  declare -A ARGS

  for key in "${JB4ARGS[@]}"
  do
    VAL=`sed -n '/data:/,$p' < ${FILEPATH}/destinationData | grep -w "${key}:" | sed "s/  ${key}: //"`
    if [[ -z "${VAL}" ]] 
    then
      VAL=0
    fi
    ARGS[${key}]=${VAL}
    #Handle the private key
    if [[ -f "${ARGS['privatekey']}" ]]; then
      SSHKEY="${ARGS['privatekey']}"
    else
      cp $JB4SSHKEY $JB5SSHKEY
      SSHKEY=$JB5SSHKEY
      ARGS['privatekey']=$SSHKEY
    fi
    echo "${key} : ${ARGS[$key]}" >> $workspace
    
  done
  echo "disabled : 1" >> $workspace
  echo "" >> $workspace
  echo "We will be using a private SSH Key generated from JetBackup 4 to reauthenticate the SSH Destination ${NAME}." >> $workspace
  #printDefaultDisabled

########## building command ###############
CMD="jetbackup5api -F manageDestination -D 'action=create&type=SSH&name=${ARGS[name]}&disabled=1&dr=${ARGS[dr]}&hidden=${ARGS[hidden]}&options[path]=${ARGS[path]}&disk_limit=${ARGS[disklimit]}&options[rsyncbwlimit]=${ARGS[rsyncbwlimit]}&options[host]=${ARGS[host]}&options[port]=${ARGS[port]}&options[privatekey]=${SSHKEY}&options[username]=${ARGS[username]}'"
#eval $CMD
echo $CMD >> $workspace
}

