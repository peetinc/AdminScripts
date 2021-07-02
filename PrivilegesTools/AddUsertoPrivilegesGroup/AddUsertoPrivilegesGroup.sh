#!/bin/bash

: <<'CommentBlock-StartandEND'

# Script Name:              CreateGroup and AddUsertoGroup.sh
# Script Author:            Peet McKinney @ Artichoke Consulting

# Changelog                 
2021.07.02                 Initial Checkin                 PJM

#Desription
This script will create a hard-coded local group and add a $1 supplied user to the group.
		
CommentBlock-StartandEND

# Ensure that local "Privileges Users" group exists
GROUP="_sap-privs"
GROUP_REALNAME="Privileges Users"
HIDDEN=0 #Hidden=1, Visible=0
USER_NAME=$1

# Functions
CreateNewGroup () {
# get unique id numbers (uid, gid) that are greater than 600
	unset -v i NEW_UID NEW_GID IDVAR
	declare -i NEW_UID=0 NEW_GID=0 i=600 IDVAR=0
	
	while [[ $IDVAR -eq 0 ]]; do 
	   i=$[i+1]
	   if [[ -z "$(dscl . -search /Users uid $i)" ]] && [[ -z "$(dscl . -search /Groups gid $i)" ]]; then
	     NEW_UID=$i
	     NEW_GID=$i
	     IDVAR=1
	   fi
	done
	
	if [[ $NEW_UID -eq 0 ]] || [[ $NEW_GID -eq 0 ]];then 
		echo 'Getting unique id numbers (uid, gid) failed!'
		exit 1
	fi
		echo "SUCCESS: $GROUP_REALNAME does not exist and will be created with GID $NEW_GID"
	    dscl . create /Groups/"$1"
	    dscl . append /Groups/"$1" RealName "$GROUP_REALNAME"
	    dscl . append /Groups/"$1" gid "$NEW_GID"
	    dscl . append /Groups/"$1" passwd "*"
	    dscl . append /Groups/"$1" IsHidden "$HIDDEN"
}

AddUserToGroup () {
	if dseditgroup -o checkmember -m $1 $2 >> /dev/null 2>&1;then
	echo "Info: $1 already member of $2"
	else
	if dseditgroup -o edit -a $1 -t user $2 >> /dev/null 2>&1;then
		echo "Success: $1 added to $2"
		else
		echo "Failure: $1 not added to $2"
		exit 1
	fi
	fi	
}

#if $GROUP does not exist ...
if ! dscl . list /Groups/"$GROUP" >> /dev/null 2>&1;then
	CreateNewGroup $GROUP
fi
#if $USER_NAME is valid ...
if id $1 >> /dev/null 2>&1;then
	AddUserToGroup $USER_NAME $GROUP
else
	echo "Error: $1 not a valid user."
	exit 1
fi