#!/bin/bash
# filepath: ~/.config/polybar/scripts/network_status.sh

export POLYBAR_COLOR_PRIMARY="#82aaff"
export POLYBAR_COLOR_ALERT="#ff757f"

# Detect interface
interface=$(ip route | awk '/default/ {print $5; exit}')

# Get wired and wifi status
wired_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="ethernet" && $3=="connected" {print $1}')
wifi_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="wifi" && $3=="connected" {print $1}')

if [ -z "$interface" ]; then
    echo "%{F$POLYBAR_COLOR_ALERT} Disconnected%{F-}"
    exit 0
fi

# Get download speed (MB/s)
rx_prev=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
sleep 1
rx_next=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
speed_bytes=$((rx_next - rx_prev))
speed_mb=$(awk "BEGIN {printf \"%.2f\", $speed_bytes/1024/1024}")

if [ -n "$wired_connected" ]; then
    echo "%{F$POLYBAR_COLOR_PRIMARY}󰈀  $speed_mb MB/s%{F-}"
elif [ -n "$wifi_connected" ]; then
    echo "%{F$POLYBAR_COLOR_PRIMARY}  $speed_mb MB/s%{F-}"
else
    echo "%{F$POLYBAR_COLOR_ALERT} Disconnected%{F-}"
fi