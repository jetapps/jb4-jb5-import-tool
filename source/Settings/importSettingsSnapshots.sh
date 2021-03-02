#!/bin/bash
###################################################################
#Script Name    : Migrate JB4 to JB5
#Description    : Script to migrate all supported configurations.
#Args           :
#Author         : Richard Ryan Marroquin
#Email          : richard@jetapps.com
###################################################################

############## GLOBAL VARIABLES ##################
BOOLEAN=("Yes" "No")
FILEPATH=$(pwd)/source/files
snapARGS=("backup" "maxperaccount" "ttl")
Workspace=$(pwd)/source/tmp

source $(pwd)/source/functions.sh

jetapi backup -F getSettingsSnapshots > ${FILEPATH}/settings
####### Get Snapshot Settings #########
tmpSpace=$Workspace/snapSettings
touch $tmpSpace

echo "Gathering Snapshot Settings"
echo "Here are the Snapshot Settings to be imported: " >> $tmpSpace
declare -A ARGS

for key in "${snapARGS[@]}"
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

CMD="jetbackup5api -F manageSettingsSnapshots -D 'action=modify&retain=${ARGS[maxperaccount]}&ttl=${ARGS[ttl]}"
echo $CMD >> $tmpSpace

