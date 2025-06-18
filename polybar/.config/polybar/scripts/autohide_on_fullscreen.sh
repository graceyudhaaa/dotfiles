#!/bin/bash
# filepath: ~/.config/polybar/autohide_on_fullscreen.sh

BAR_NAME="main"
CHECK_INTERVAL=0.5

was_fullscreen=0

while true; do
    # Get the currently active window ID
    active_win=$(xprop -root _NET_ACTIVE_WINDOW | awk -F' ' '{print $5}')
    # Remove "0x" prefix if present
    active_win=${active_win#0x}
    # If no active window, treat as not fullscreen
    if [ -z "$active_win" ]; then
        is_fullscreen=0
    else
        # Check if the active window is Polybar
        if xprop -id "0x$active_win" WM_CLASS 2>/dev/null | grep -qi "Polybar"; then
            is_fullscreen=0
        # Check if the active window is fullscreen
        elif xprop -id "0x$active_win" _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_FULLSCREEN"; then
            is_fullscreen=1
        else
            is_fullscreen=0
        fi
    fi

    if [ "$is_fullscreen" -eq 1 ] && [ "$was_fullscreen" -eq 0 ]; then
        pkill polybar
        was_fullscreen=1
    elif [ "$is_fullscreen" -eq 0 ] && [ "$was_fullscreen" -eq 1 ]; then
        polybar main --config=~/.config/polybar/config.ini &
        was_fullscreen=0
    fi

    sleep "$CHECK_INTERVAL"
done