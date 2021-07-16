#!/bin/bash

: <<'CommentBlock-StartandEND'

# Script Name:              RevokePrivileges.sh
# Script Author:            Peet McKinney @ Artichoke Consulting

# Changelog                 
2021.07.02                 Initial Checkin                 PJM

#Desription
This script revoke Privilige.app enabled user from admin group. The script accepts 1 arguemnt for $TIMER. The number of seconds before executing.
We default to 10minutes for admin.

CommentBlock-StartandEND

### Variables 
# The assumption here is that user 501 should be the sole admin. 
# However any admin name can be added to the ${VALID_ADMINS[@]} array
CONOLE_USER=$(stat -f "%Su" /dev/console)
FIRST_ADMIN=$(id -nu 501)
VALID_ADMINS=(root $FIRST_ADMIN)
# Default time as admin in seconds
TIMEOUT_DEFAULT=600

## Runtime Variables
ADMIN_UUID=($(dscl . -read Groups/admin GroupMembers  | cut -c 15-))
ADMIN_MEMBERS=($(dscl . -read Groups/admin GroupMembership | cut -c 18-))
for U in "${VALID_ADMINS[@]}"; do
	VALID_ADMINS_UUID+=($(dsmemberutil getuuid -U $U))
done

# Set admin time to $1 if provided, $TIMEOUT_DEFAULT if not
if [ $# -ne 1 ]; then
    TIMER=$TIMEOUT_DEFAULT
    else
    TIMER=$1
fi

### Functions
# This is a quick check if string is in the array (usage -- Check-Array ARRAY_NAME SEARCH_STRING)
Check-Array () { 
    local ARRAY="$1[@]"
    local RESULT=1
    for i in "${!ARRAY}"; do
        if [[ $i == "$2" ]]; then
            RESULT=0
            break
        fi
    done
    return $RESULT
}

# This checks all . /Users against ./Groups/admin to see if they're part of the group.
# (usage -- Get-Members GROUPNAME)
Get-Members () {
	if [[ -z $1 ]]; then
	    echo "A group name needs to be provided."
	    exit 1
	fi
	
	if ! dscl /Search read /Groups/"$1" 1>/dev/null; then
	    echo "A group with the name $1 does not exist."
	    exit 1
	fi
	
	NODE=${2:-"/Local/Default"}
	
	for U in $(dscl "$NODE" list /Users ); do
	    if dseditgroup -o checkmember -m "$U" "$1" 1>/dev/null; then
	        echo "$U"
	    fi
	done
}

# In case someone was cheeky and set their PGID to 80 ...
Revoke-PrimaryGroupIDAdmin () {
	PGID_ADMINS=($(dscl . list /Users PrimaryGroupID | awk '$2=='80' { print $1; }'))
	if ! [ -z ${PGID_ADMINS[@]} ]; then 
		for staff in "${PGID_ADMINS[@]}"; do
			sudo dscl . create /Users/$staff PrimaryGroupID 20
			echo "WARNING: Set $staff PrimaryGroupID to 20"
		done
	fi
}

# In case someone was really cheeky and enabled root
Disable-Root () {
	if dscl . -read /Users/root Password | grep -q '\*\*\*\*\*\*\*\*' || dscl . -read /Users/root AuthenticationAuthority | grep -q -e 'ShadowHash' -e 'SecureToken' -e 'Kerberosv5';then
		echo "WARNING: root user was enabled ... Disabling."
		dscl . -delete /Users/root AuthenticationAuthority
		dscl . -change /Users/root Password "********" "*"
	fi
}

# Remove any nested groups from admin if present
Remove-AdminNestedGroup () {
	if defaults read /var/db/dslocal/nodes/Default/groups/admin.plist nestedgroups > /dev/null 2>&1; then
		dscl . -delete /Groups/admin NestedGroups
 		echo "WARNING: Removed NestedGroups from admin group."
	fi
}


### MAIN
# Take a few minutes
sleep $TIMER

# We need to make sure to not de-privilege $FIRST_ADMIN
if [ -f "/Applications/Privileges.app/Contents/Resources/PrivilegesCLI" ] && ! Check-Array VALID_ADMINS $CONOLE_USER; then
	su "$CONOLE_USER" -c "/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove"
fi

# Remove ${VALID_ADMINS_UUID[@]} from ${ADMIN_UUID[@]}
for target in "${VALID_ADMINS_UUID[@]}"; do
  for i in "${!ADMIN_UUID[@]}"; do
    if [[ ${ADMIN_UUID[i]} = $target ]]; then
      unset 'ADMIN_UUID[i]'
    fi
  done
done

# Finally remove all ${ADMIN_UUID[@]} from the admin GroupMembers
for del in "${ADMIN_UUID[@]}"; do
	dscl . -delete /Groups/admin GroupMembers "$del"
	echo "WARNING: Removed UUID $del from GroupMembers in admin group."
done


# Remove ${VALID_ADMINS[@]} from ${ADMIN_MEMBERS[@]}
for target in "${VALID_ADMINS[@]}"; do
  for i in "${!ADMIN_MEMBERS[@]}"; do
    if [[ ${ADMIN_MEMBERS[i]} = $target ]]; then
      unset 'ADMIN_MEMBERS[i]'
    fi
  done
done

# Finally remove all ${UNIQUE_MEMBERS[@]} from the admin group
for del in "${ADMIN_MEMBERS[@]}"; do
	/usr/sbin/dseditgroup -o edit -d $del -t user admin
	echo "WARNING: Removed $del from admin group"
done

Remove-AdminNestedGroup
Revoke-PrimaryGroupIDAdmin
Disable-Root

exit 0