#!/bin/bash
# filepath: ~/.config/polybar/scripts/network_status.sh

# Get active connection name (SSID) using nmcli
ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
wired_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="ethernet" && $3=="connected" {print $1}')

export POLYBAR_COLOR_PRIMARY="#82aaff"
export POLYBAR_COLOR_ALERT="#ff757f"

if [ -n "$wired_connected" ]; then
    # Wired connection active
    echo "%{F$POLYBAR_COLOR_PRIMARY} Wired%{F-}"
elif [ -n "$ssid" ]; then
    # Connected: show Wi-Fi icon and SSID
    # Clip SSID if longer than 10 characters
    if [ ${#ssid} -gt 10 ]; then
        ssid="${ssid:0:7}..."
    fi
    echo "%{F$POLYBAR_COLOR_PRIMARY} $ssid%{F-}"
else
    # Not connected: show disconnected icon
    echo "%{F$POLYBAR_COLOR_ALERT} Disconnected%{F-}"
fi