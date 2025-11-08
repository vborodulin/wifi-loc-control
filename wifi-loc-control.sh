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


# Get the Wi-Fi interface name
get_wifi_interface() {
  networksetup -listallhardwareports | grep -A1 'Hardware Port: Wi-Fi' | tail -1 | awk '{print $2}'
}

# Get the Wi-Fi network name (SSID)
# Try multiple methods for compatibility with different macOS versions
get_wifi_name() {
  wifi_interface="$(get_wifi_interface)"

  # Method 1: Try the new approach for macOS 26+ (Sequoia 15.6+)
  if command -v ipconfig >/dev/null 2>&1; then
    # First try without sudo (might work in some cases)
    wifi_name_new=$(ipconfig getsummary "$wifi_interface" 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2}' | tr -d '\n')
    
    if [[ -n "$wifi_name_new" && "$wifi_name_new" != "<redacted>" && "$wifi_name_new" != "< redacted >" ]]; then
      echo "$wifi_name_new"
      return 0
    fi
    
    # Try with sudo verbose mode for macOS 26+
    if sudo -n ipconfig setverbose 1 >/dev/null 2>&1; then
      sudo ipconfig setverbose 1 >/dev/null 2>&1
      wifi_name_verbose=$(ipconfig getsummary "$wifi_interface" 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2}' | tr -d '\n')
      sudo ipconfig setverbose 0 >/dev/null 2>&1
      
      if [[ -n "$wifi_name_verbose" && "$wifi_name_verbose" != "<redacted>" && "$wifi_name_verbose" != "< redacted >" ]]; then
        echo "$wifi_name_verbose"
        return 0
      fi
    fi
  fi
  
  # Method 2: Try PlistBuddy approach (works on older macOS versions)
  wifi_name_plist=$(/usr/libexec/PlistBuddy -c 'Print :0:_items:0:spairport_airport_interfaces:0:spairport_current_network_information:_name' /dev/stdin <<< "$(system_profiler SPAirPortDataType -xml)" 2>/dev/null)
  
  if [[ -n "$wifi_name_plist" && "$wifi_name_plist" != "<redacted>" && "$wifi_name_plist" != "< redacted >" ]]; then
    echo "$wifi_name_plist"
    return 0
  fi
  
  # Method 3: Fallback to original method (for older macOS)
  wifi_name_fallback=$(networksetup -listpreferredwirelessnetworks "$wifi_interface" | sed -n '2 p' | tr -d '\t')
  
  if [[ -n "$wifi_name_fallback" && "$wifi_name_fallback" != "<redacted>" && "$wifi_name_fallback" != "< redacted >" ]]; then
    echo "$wifi_name_fallback"
    return 0
  fi
  
  # If all methods fail, return empty
  echo ""
}

# Get the Wi-Fi MAC address used for the current network.
# By default, macOS assigns a unique and random MAC address to each SSID, allowing to map networks to locations.
get_wifi_mac_address() {
  wifi_interface="$(get_wifi_interface)"
  ifconfig "$wifi_interface" | awk '/ether/{print $2}'
}

wifi_name="$(get_wifi_name)"
wifi_mac_address="$(get_wifi_mac_address)"
log "current wifi_name '$wifi_name' and wifi_mac_address '$wifi_mac_address'"

if [[ ( "$wifi_name" == "" || "$wifi_name" == "<redacted>" || "$wifi_name" == "< redacted >" ) && "$wifi_mac_address" == "" ]]; then
  log "wifi_name is empty or redacted, and wifi_mac_address is empty"
  exit 0
fi

# Get a list of available network locations
network_locations=$(scselect | sed -n 's/^ .*(\(.*\))/\1/p' | xargs)
log "network locations: $network_locations"

# Get the current network location
current_network_location=$(scselect | sed -n 's/ \* .*(\(.*\))/\1/p')
log "current network location '$current_network_location'"

# Check if an alias is defined for the current Wi-Fi network
alias_location=$wifi_name
if [ -f "$ALIAS_CONFIG_PATH" ]; then
  log "reading alias config '$ALIAS_CONFIG_PATH'"
  wifi_alias=$(awk -v key="$wifi_name" -F'=' '$1 == key { print $2 }' "$ALIAS_CONFIG_PATH")
  mac_alias=$(awk -v key="$wifi_mac_address" -F'=' 'tolower($1) == tolower(key) { print $2 }' "$ALIAS_CONFIG_PATH")

  if [ "$wifi_alias" != "" ]; then
    alias_location=$wifi_alias
    log "for wifi_name '$wifi_name' found alias '$alias_location'"
  elif [ "$mac_alias" != "" ]; then
    alias_location=$mac_alias
    log "for wifi_mac_address '$wifi_mac_address' found alias '$alias_location'"
  else
    log "for wifi_name '$wifi_name' and wifi_mac_address '$wifi_mac_address' alias not found"
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
  scselect "$new_location"
  log "location switched to '$new_location'"
  exec_location_script "$new_location"
  exit 0
fi

if [ "$alias_location" != "$current_network_location" ]; then
  new_location=$alias_location
  scselect "$new_location"
  log "location switched to '$new_location'"
  exec_location_script "$new_location"
  exit 0
fi

# If none of the conditions are met, no location switch is required
log "switch location is not required"
