#!/usr/bin/env bash

LOGS_PATH=$HOME/Library/Logs/WiFiLocControl.log
DEFAULT_NETWORK_LOCATION=Automatic
CONFIG_DIR=$HOME/.wifi-loc-control
ALIAS_CONFIG_PATH=$CONFIG_DIR/alias.conf

# redirecting both standard output and standard error to the same location and appending
# it to a log file under the user's home directory ($HOME).
exec >> "$LOGS_PATH" 2>&1

# allow time for file descriptors to be set up and log file to be created
sleep 3

# Function to log messages with a timestamp
log() {
  current_date=$(date +"[%Y-%m-%d %H:%M:%S]")
  echo -e "$current_date $*"
}

# Get the Wi-Fi network name (SSID)
wifi_name="$(/usr/libexec/PlistBuddy -c 'Print :0:_items:0:spairport_airport_interfaces:0:spairport_current_network_information:_name' /dev/stdin <<< "$(system_profiler SPAirPortDataType -xml)" 2> /dev/null)"
log "current wifi_name '$wifi_name'"

if [ "$wifi_name" == "" ]; then
  log "wifi_name is empty"
  exit 0
fi

# Get a list of available network locations
network_locations=$(networksetup -listlocations | xargs)
log "network locations: $network_locations"

# Get the current network location
current_network_location=$(networksetup -getcurrentlocation)
log "current network location '$current_network_location'"

# Check if an alias is defined for the current Wi-Fi network
alias_location=$wifi_name
if [ -f "$ALIAS_CONFIG_PATH" ]; then
  log "reading alias config '$ALIAS_CONFIG_PATH'"
  alias=$(grep "$wifi_name=" "$ALIAS_CONFIG_PATH" | sed -nE 's/.*=(.*)/\1/p')

  if [ "$alias" != "" ]; then
    alias_location=$alias
    log "for wifi name '$wifi_name' found alias '$alias_location'"
  else
    log "for wifi name '$wifi_name' alias not found"
  fi
fi

exec_location_script() {
  location=$1
  script_file="$CONFIG_DIR/$location"

  log "finding script for location '$location'"

  if [ -f "$script_file"  ]; then
    log "running script '$script_file'"
    chmod +x "$script_file"
    "$script_file"
  else
    log "script for location '$location' not found"
  fi
}

# Check if the alias is a valid network location
has_related_network_location=$(echo "$network_locations" | grep "$alias_location" && echo "true" || echo "false")

if [[ "$has_related_network_location" == "false" && "$current_network_location" == "$DEFAULT_NETWORK_LOCATION" ]]; then
  log "switch location is not required"
  exit 0
fi

if [ "$has_related_network_location" == "false" ]; then
  new_location=$DEFAULT_NETWORK_LOCATION
  networksetup -switchtolocation "$new_location"
  log "location switched to '$new_location'"
  exec_location_script "$new_location"
  exit 0
fi

if [ "$alias_location" != "$current_network_location" ]; then
  new_location=$alias_location
  networksetup -switchtolocation "$new_location" > /dev/null
  log "location switched to '$new_location'"
  exec_location_script "$new_location"
  exit 0
fi

# If none of the conditions are met, no location switch is required
log "switch location is not required"
