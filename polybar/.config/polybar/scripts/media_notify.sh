#!/usr/bin/env bash

# Shared notification helper for media actions
NOTIFY_ICON="media-playback-start"

# Get current player status
get_status() {
    playerctl status 2>/dev/null || echo "No player"
}

# Get metadata
get_metadata() {
    local artist=$(playerctl metadata artist 2>/dev/null)
    local title=$(playerctl metadata title 2>/dev/null)
    
    if [ -z "$artist" ] || [ -z "$title" ]; then
        echo "No media playing"
    else
        echo "$artist - $title"
    fi
}

# Get album art URL
get_album_art() {
    playerctl metadata --format "{{ mpris:artUrl }}" 2>/dev/null
}

# Get status icon
get_status_icon() {
    local status=$(get_status)
    case "$status" in
        "Playing") echo "󰐊" ;;
        "Paused") echo "󰏤" ;;
        *) echo "󰎆" ;;
    esac
}

# Get notification icon (prefer album art, fallback to icon)
get_notify_icon() {
    local art_url=$(get_album_art)
    
    if [ -n "$art_url" ]; then
        # Handle file:// URLs
        if [[ "$art_url" =~ ^file:// ]]; then
            echo "${art_url#file://}"
        else
            echo "$art_url"
        fi
    else
        echo "$NOTIFY_ICON"
    fi
}

action="$1"

case "$action" in
    play-pause)
        playerctl play-pause
        sleep 0.3
        notify-send -i "$(get_album_art)" "$(get_metadata)" "$(playerctl status 2>/dev/null)"
        ;;
    next)
        playerctl next
        wait_for_metadata
        sleep 1  # Small delay to ensure metadata is updated
        notify-send -i "$(get_notify_icon)" "$(get_metadata)" "Next Track"
        ;;
    previous)
        local was_playing=$(get_status)
        playerctl position 0
        playerctl pause
        playerctl previous
        [ "$was_playing" = "Playing" ] && playerctl play
        wait_for_metadata
        sleep 1  # Small delay to ensure metadata is updated
        notify-send -i "$(get_notify_icon)" "$(get_metadata)" "Previous Track"
        ;;
esac