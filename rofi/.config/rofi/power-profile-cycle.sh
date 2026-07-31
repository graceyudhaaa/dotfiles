#!/bin/bash

# Get current profile
CURRENT=$(powerprofilesctl get)

# Cycle through profiles
case "$CURRENT" in
    "performance")
        powerprofilesctl set balanced
        notify-send -i "battery" "Power Profile" "Switched to Balanced" -t 2000
        ;;
    "balanced")
        powerprofilesctl set power-saver
        notify-send -i "battery" "Power Profile" "Switched to Power Saver" -t 2000
        ;;
    "power-saver")
        powerprofilesctl set performance
        notify-send -i "battery" "Power Profile" "Switched to Performance" -t 2000
        ;;
esac