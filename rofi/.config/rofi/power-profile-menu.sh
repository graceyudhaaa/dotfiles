#!/bin/bash

ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"

CURRENT=$(powerprofilesctl get)
PROFILE=$(echo -e "Performance\nBalanced\nPower Saver" | rofi -dmenu -theme "$ROFI_THEME" -p "Power Profile (Current: $CURRENT)")

case "$PROFILE" in
    "Performance")
        powerprofilesctl set performance
        notify-send -i "battery" "Power Profile" "Switched to Performance" -t 2000
        ;;
    "Balanced")
        powerprofilesctl set balanced
        notify-send -i "battery" "Power Profile" "Switched to Balanced" -t 2000
        ;;
    "Power Saver")
        powerprofilesctl set power-saver
        notify-send -i "battery" "Power Profile" "Switched to Power Saver" -t 2000
        ;;
esac