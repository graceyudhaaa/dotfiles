#!/bin/bash

export POLYBAR_COLOR_PRIMARY="#82aaff"
export POLYBAR_COLOR_ALERT="#ff757f"

# Detect interface
interface=$(ip route | awk '/default/ {print $5; exit}')

# Get wired and wifi status
wired_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="ethernet" && $3=="connected" {print $1}')
wifi_connected=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="wifi" && $3=="connected" {print $1}')

if [ -z "$interface" ]; then
    echo "%{F$POLYBAR_COLOR_ALERT}󰤭%{F-}"
    exit 0
fi

# Get download speed
rx_prev=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
sleep 1
rx_next=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
speed_bytes=$((rx_next - rx_prev))

# Auto-select unit: KB/s or MB/s
speed_kb=$(awk "BEGIN {printf \"%.0f\", $speed_bytes/1024}")
if [ "$speed_bytes" -ge 1048576 ]; then
    speed=$(awk "BEGIN {printf \"%.1f\", $speed_bytes/1048576}")
    unit="M"
elif [ "$speed_bytes" -ge 1024 ]; then
    speed=$speed_kb
    unit="K"
else
    speed="0"
    unit="K"
fi

if [ -n "$wired_connected" ]; then
    echo "%{F$POLYBAR_COLOR_PRIMARY}󰈀 ${speed}${unit}%{F-}"
elif [ -n "$wifi_connected" ]; then
    echo "%{F$POLYBAR_COLOR_PRIMARY}  ${speed}${unit}%{F-}"
else
    echo "%{F$POLYBAR_COLOR_ALERT}󰤭%{F-}"
fi