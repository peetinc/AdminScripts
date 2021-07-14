#!/bin/bash

# Generate a timestamp
now=$(date +"%Y%m%d_%H%M%S")
# Stop the server
cd /opt
if [ -d "/opt/SimpleHelp" ]; then
        cd SimpleHelp
        sh serverstop.sh
        cd ..
        echo "Backing up the SimpleHelp installation to SimpleHelp_backup_$now"
        mv SimpleHelp "SimpleHelp_backup_$now"
fi
# Fetch the new version
echo "Downloading the latest version"
if [ `uname -m | grep "64"` ]; then
        rm -f SimpleHelp-linux-amd64.tar.gz
        wget https://simple-help.com/releases/beta53/SimpleHelp-linux-amd64.tar.gz
        tar -xzf SimpleHelp-linux-amd64.tar.gz
else
        rm -f SimpleHelp-linux-tar.gz
        wget https://simple-help.com/releases/beta53/SimpleHelp-linux.tar.gz
        tar -xzf SimpleHelp-linux.tar.gz
fi
# Copy across the old configuration folder
if [ -d "/opt/SimpleHelp_backup_$now" ]; then
    echo "Copying across configuration files"
    cp -R /opt/SimpleHelp_backup_$now/configuration/* /opt/SimpleHelp/configuration
    # Copy across a legacy license file
    if [ -f "/opt/SimpleHelp_backup_$now/shlicense.txt" ]; then
            cp /opt/SimpleHelp_backup_$now/shlicense.txt /opt/SimpleHelp/configuration
    fi
    # Copy across any keystore file
    if [ -f "/opt/SimpleHelp_backup_$now/keystore" ]; then
            cp /opt/SimpleHelp_backup_$now/keystore /opt/SimpleHelp
    fi
fi
# Start the new server
echo "Starting your new SimpleHelp server"
cd SimpleHelp
sh serverstart.sh
cd ..