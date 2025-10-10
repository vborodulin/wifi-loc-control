# WiFiLocControl

WiFiLocControl allows you to change your
macOS [network location](https://support.apple.com/en-us/105129) automatically based on the Wi-Fi
network (SSID) you are connected to. It is particularly useful for users who use Wi-Fi at work and
at home, but the network settings (for example, custom DNS configurations) you use at work don't
allow your Mac to automatically connect to the same type of network at home.

## Features

- Automatically changes network locations based on current Wi-Fi name.
- Supports alias configurations for multiple Wi-Fi names.
- Executes location-specific scripts.

## Installation


1. Clone the repository to your local machine.
  ```bash
  git clone https://github.com/ctrlcmdshft/wifi-loc-control.git
  cd wifi-loc-control
  ```

2. Run the bootstrap script to set up the environment.
  ```bash
  chmod +x bootstrap.sh
  ./bootstrap.sh
  ```
   It will **ask you for a root password** to install WiFiLocControl to the `/usr/local/bin` directory and set up required permissions for macOS 26+.

3. (Optional) Create an alias configuration file to map Wi-Fi names to locations:
  ```bash
  mkdir -p ~/.wifi-loc-control
  nano ~/.wifi-loc-control/alias.conf
  ```
  Example contents:
  ```
  Unifi=Home
  Unifi6=Home
  Firewall=Work
  Firewall Office=Work
  ```

4. To check logs for activity:
  ```bash
  tail -f ~/Library/Logs/WiFiLocControl.log
  ```

5. To uninstall, run:
  ```bash
  sudo rm /usr/local/bin/wifi-loc-control.sh
  rm -rf ~/.wifi-loc-control
  rm ~/Library/LaunchAgents/WiFiLocControl.plist
  sudo rm /etc/sudoers.d/wifi-loc-control
  launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/WiFiLocControl.plist
  ```

## Usage
To set up specific preferences for your Wi-Fi networks, keep it easy: just name your network locations after
your Wi-Fi names. For example, if you want special settings for `My_Home_Wi-Fi_5GHz`, make a
location called `My_Home_Wi-Fi_5GHz`. When you connect to that Wi-Fi, your location will switch
automatically. If you connect to a Wi-Fi without a special name, it defaults to `Automatic`.

## Configuration

### Aliasing

If you want to share one network location between different wireless networks (for instance, you
have a wireless router which broadcasts on 2.4 and 5GHz bands simultaneously), then you can create a
configuration file `~/.wifi-loc-control/alias.conf` (plain text file with simple key-value pairs, no
spaces in between):

```text
My_Home_Wi-Fi_5GHz=Home
My_Home_Wi-Fi_2.4GHz=Home
```

Where the keys are the wireless network names and the values are the desired location names.

### Run Scripts on Wi-Fi Network Connection

Sometimes you want to execute a script every time you connect to a specific Wi-Fi network. For
example enable stealth or enable firewall mode. Follow these
steps:

- Place your scripts in `~/.wifi-loc-control/`.
- Name the scripts after the Wi-Fi network name, ensuring consistency with the corresponding
  network locations.

Example script (`~/.wifi-loc-control/My_Home_Wi-Fi_5GHz`):

```bash
#!/usr/bin/env bash
# Collect all output from this script to ~/Library/Logs/WiFiLocControl.log
exec 2>&1

# Enable stealth mode which makes your computer less visible to potential attackers
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

To reset changes made by specific location scripts, create corresponding reset script.
Example reset script (`~/.wifi-loc-control/Automatic`):

```bash
#!/usr/bin/env bash
exec 2>&1

# Disable stealth mode which makes your computer less visible to potential attackers
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
```

Make scripts executable

```bash
chmod +x ~/.wifi-loc-control/My_Home_Wi-Fi_5GHz
chmod +x ~/.wifi-loc-control/Automatic
```

## Troubleshooting

Rich logs available at ~/Library/Logs/WiFiLocControl.log.

```bash
tail -f ~/Library/Logs/WiFiLocControl.log
```

Logs examples:

```text
[2023-11-26 13:44:49] current wifi_name 'My_Home_Wi-Fi_5GHz'
[2023-11-26 13:44:49] network locations: Automatic Home
[2023-11-26 13:44:49] current network location 'Automatic'
[2023-11-26 13:44:49] reading alias config '/Users/vborodulin/.wifi-loc-control/alias.conf'
[2023-11-26 13:44:49] for wifi name 'My_Home_Wi-Fi_5GHz' found alias 'Home'
[2023-11-26 13:44:49] location switched to 'Home'
[2023-11-26 13:44:49] finding script for location 'Home'
[2023-11-26 13:44:49] running script '/Users/vborodulin/.wifi-loc-control/Home'
```

## Contributing

Contributions are welcome! If you have suggestions, improvements, or encounter issues, feel free to
open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
