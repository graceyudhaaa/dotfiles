#!/bin/bash

export POLYBAR_COLOR_PRIMARY="#82aaff"
export POLYBAR_COLOR_ALERT="#ff757f"

# Detect interface
interface=$(ip route | awk '/default/ {print $5; exit}')

# Get wired and wifi status
wired_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="ethernet" && $3=="connected" {print $1}')
wifi_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="wifi" && $3=="connected" {print $1}')

# Get signal strength for WiFi
get_signal_ramp() {
    local signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi | awk -F: '$1=="*" {print $2}')
    if [ -z "$signal" ]; then
        signal=0
    fi
    
    # Convert signal strength to ramp visualization
    if [ "$signal" -lt 25 ]; then
        echo "󰤟"
    elif [ "$signal" -lt 50 ]; then
        echo "󰤢"
    elif [ "$signal" -lt 75 ]; then
        echo "󰤥"
    else
        echo "󰤨"
    fi
}

if [ -z "$interface" ]; then
    echo "%{F$POLYBAR_COLOR_ALERT}󰤭%{F-}"
    exit 0
fi

if [ -n "$wired_connected" ]; then
    echo "%{F$POLYBAR_COLOR_PRIMARY}󰈀"
elif [ -n "$wifi_connected" ]; then
    signal_ramp=$(get_signal_ramp)
    echo "%{F$POLYBAR_COLOR_PRIMARY}$signal_ramp "
else
    echo "%{F$POLYBAR_COLOR_ALERT}󰤭%{F-}"
fi