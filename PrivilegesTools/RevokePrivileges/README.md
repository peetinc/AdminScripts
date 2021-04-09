# RevokePrivileges
A LaunchDaemon, a LaunchAgent, and a small bash script that keeps an eye on the membership of `. /groups/admin`. Anytime theres a change to `/var/db/dslocal/nodes/Default/groups/admin.plist`, the LaunchDaemon fires the script which by default sleeps for 600 seconds, then removes all but root and user 501 from the admin group.

A LaunchAgent that only runs at the LoginWindow fires the script every time the computer hits the LoginWindow just incase the script was unable to clear the extra users from the admin group.

Is it perfect? Probably not, but it does work and and it does keep administrative access to only the admin's that you set. It even has a bit of cheeky sneak detection to make sure no one has set their `PrimaryGroupID` to 80 to maintain admin priviliges without being a direct member of the admin group. If they do, it resets the `PrimaryGroupID` to 20.

This folder is a [munkipkg](https://github.com/munki/munki-pkg) project build an installer with:

`munkipkg ./RevokePrivileges`
