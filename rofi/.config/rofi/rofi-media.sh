#!/usr/bin/env bash

# Media Control Script using playerctl and rofi

ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"
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

# Main menu
show_menu() {
    local status=$(get_status)
    local metadata=$(get_metadata)
    local icon=$(get_status_icon)
    
    local menu_items="󰎙  Play/Pause
󰒭  Next Track
󰒮  Previous Track
󰋇  Show Status
󰋙  Show Metadata"
    
    local mesg="$(echo -e "$icon $(echo "$status" | tr '[:lower:]' '[:upper:]')\n$metadata")"
    
    echo "$menu_items" | rofi -dmenu -theme "$ROFI_THEME" -p "Media Control" -mesg "$mesg"
}


# Wait for player state to change, with timeout fallback
wait_for_change() {
    local before=$(get_status)
    local attempts=0
    while [ $attempts -lt 10 ]; do
        local current=$(get_status)
        [ "$current" != "$before" ] && return 0
        sleep 0.05
        ((attempts++))
    done
}


# Wait for metadata to change, with timeout fallback
wait_for_metadata() {
    local before=$(get_metadata)
    local attempts=0
    while [ $attempts -lt 40 ]; do
        local artist=$(playerctl metadata artist 2>/dev/null)
        local title=$(playerctl metadata title 2>/dev/null)

        # Only return when we have valid, different metadata
        if [ -n "$artist" ] && [ -n "$title" ]; then
            local current="$artist - $title"
            if [ "$current" != "$before" ]; then
                return 0
            fi
        fi

        sleep 0.05
        ((attempts++))
    done
}

# Execute action
execute_action() {
    local choice="$1"
    
    case "$choice" in
        *"Play/Pause"*)
            playerctl play-pause
            wait_for_change
            notify-send -i "$(get_notify_icon)" "$(get_metadata)" "$(get_status)"
            ;;
        *"Next Track"*)
            playerctl next
            wait_for_metadata
            sleep 1  # Small delay to ensure metadata is updated
            notify-send -i "$(get_notify_icon)" "$(get_metadata)" "Next Track"
            ;;
        *"Previous Track"*)
            local was_playing=$(get_status)
            playerctl pause
            playerctl position 0
            playerctl previous
            [ "$was_playing" = "Playing" ] && playerctl play
            wait_for_metadata
            sleep 1  # Small delay to ensure metadata is updated
            notify-send -i "$(get_notify_icon)" "$(get_metadata)" "Previous Track"
            ;;
        *"Show Status"*)
            notify-send -i "$(get_notify_icon)" "$(get_metadata)" "$(get_status)"
            ;;
        *"Show Metadata"*)
            notify-send -i "$(get_notify_icon)" "$(get_metadata)" "Now Playing"
            ;;
    esac
}

# Run
choice=$(show_menu)
[ -n "$choice" ] && execute_action "$choice"