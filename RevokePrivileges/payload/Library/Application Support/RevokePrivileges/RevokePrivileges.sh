#!/bin/bash

: <<'CommentBlock-StartandEND'

# Script Name:              RevokePrivileges.sh
# Script Author:            Peet McKinney @ Artichoke Consulting

# Changelog                 
2020.23.07                 Initial Checkin                 PJM

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

# Set admin time to $1 if provided, $TIMEOUT_DEFAULT if not
if [ $# -ne 1 ]; then
    TIMER=$TIMEOUT_DEFAULT
    else
    TIMER=$1
fi

### Functions
# This is a quick check if string is in the array (usage -- array_contains ARRAY_NAME SEARCH_STRING)
array_contains () { 
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}

# This checks all . /Users against ./Groups/admin to see if they're part of the group.
# (usage -- members GROUPNAME)
members () 
{ dscl . -list /Users | \
	while read user 
		do printf "$user "
		dsmemberutil checkmembership -U "$user" -G "$*"
	done | grep "is a member" | cut -d " " -f 1; 
}


### MAIN
# Take a few minutes
sleep $TIMER

# We need to make sure to not de-privilege $FIRST_ADMIN
if [ -f "/Applications/Privileges.app/Contents/Resources/PrivilegesCLI" ] && ! array_contains VALID_ADMINS $CONOLE_USER; then
	su "$CONOLE_USER" -c "/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove"
fi

# Check local users for membership in admin group.
MEMBERS_ADMIN=($(members admin))

# Check admin group for users
dscl -plist . read /groups/admin > /tmp/admin.plist
ADMIN_MEMBERS=($(/usr/libexec/PlistBuddy -c "Print :dsAttrTypeStandard\:GroupMembership" /tmp/admin.plist | sed -e 1d -e '$d'))

# Combine the two arrays 
COMBINED_MEMBERS=( "${MEMBERS_ADMIN[@]}" "${ADMIN_MEMBERS[@]}")

# Clear duplicates from the combined array
UNIQUE_MEMBERS=($(printf "%s\n" "${COMBINED_MEMBERS[@]}" | sort -u))

# Remove ${VALID_ADMINS[@]} from ${UNIQUE_MEMBERS[@]}
for target in "${VALID_ADMINS[@]}"; do
  for i in "${!UNIQUE_MEMBERS[@]}"; do
    if [[ ${UNIQUE_MEMBERS[i]} = $target ]]; then
      unset 'UNIQUE_MEMBERS[i]'
    fi
  done
done

# Finally remove all ${UNIQUE_MEMBERS[@]} from the admin group
for del in "${UNIQUE_MEMBERS[@]}"; do
	/usr/sbin/dseditgroup -o edit -d $del -t user admin
	echo "WARNING: Removed $del from admin group"
done

# In case someone was cheeky and set their PGID to 80 ...
PGID_ADMINS=($(dscl . list /Users PrimaryGroupID | awk '$2=='80' { print $1; }'))

if ! [ -z ${PGID_ADMINS[@]} ]; then 
	for staff in "${PGID_ADMINS[@]}"; do
		sudo dscl . create /Users/$staff PrimaryGroupID 20
		echo "WARNING: Set $staff PrimaryGroupID to 20"
	done
fi
	
exit 0