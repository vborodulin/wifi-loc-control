#!/usr/bin/env bash

SCRIPT_NAME=wifi-loc-control.sh
INSTALL_DIR=/usr/local/bin/

LUNCH_AGENTS_DIR=$HOME/Library/LaunchAgents
LUNCH_AGENT_CONFIG_NAME=WiFiLocControl.plist
LUNCH_AGENT_CONFIG_PATH=$LUNCH_AGENTS_DIR/$LUNCH_AGENT_CONFIG_NAME

CONFIG_DIR=$HOME/.wifi-loc-control

sudo -v

mkdir -p $INSTALL_DIR
cp -f $SCRIPT_NAME $INSTALL_DIR

# Set exec permissions for script
chmod +x $INSTALL_DIR/$SCRIPT_NAME

mkdir -p $CONFIG_DIR

mkdir -p $LUNCH_AGENTS_DIR
cp -f  $LUNCH_AGENT_CONFIG_NAME $LUNCH_AGENTS_DIR

# Unload and load the launch agent
launchctl unload $LUNCH_AGENT_CONFIG_PATH > /dev/null 2>&1
launchctl load -w $LUNCH_AGENT_CONFIG_PATH

echo "WiFiLocControl has been installed and configured successfully."
