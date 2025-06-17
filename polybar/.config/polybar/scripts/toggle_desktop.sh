#!/bin/bash
# filepath: ~/.config/polybar/scripts/toggle_desktop.sh

# Check if desktop is currently shown
if wmctrl -d | grep -q '\*.*hidden'; then
    # If desktop is shown, restore windows
    wmctrl -k off
else
    # If desktop is not shown, show desktop
    wmctrl -k on
fi