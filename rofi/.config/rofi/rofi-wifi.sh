#!/bin/bash
# filepath: ~/bin/rofi-wifi.sh

ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"

get_current_ssid() {
    nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2
}

while true; do
    CURRENT_SSID=$(get_current_ssid)

    # List available SSIDs, remove empty lines, sort and uniq
    SSID=$(nmcli -t -f SSID dev wifi | grep -v '^$' | sort -u | rofi -dmenu -theme "$ROFI_THEME" -p "Select WiFi SSID")
    [ -z "$SSID" ] && exit 0

    # If already connected to this SSID, disconnect
    if [ "$SSID" = "$CURRENT_SSID" ]; then
        nmcli connection down "$SSID"
        notify-send "WiFi" "Disconnected from $SSID"
        exit 0
    fi

    # Check if a connection profile exists for this SSID
    if nmcli connection show | grep -q "$SSID"; then
        # Try to connect using the saved profile
        nmcli connection up "$SSID" >/tmp/rofi-wifi.log 2>&1
        if grep -q "successfully activated" /tmp/rofi-wifi.log; then
            notify-send "WiFi" "Connected to $SSID"
            exit 0
        else
            rofi -theme "$ROFI_THEME" -e "Failed to connect with saved profile! Trying password..."
        fi
    fi

    # Prompt for password if not connected
    PASS=$(rofi -dmenu -password -theme "$ROFI_THEME" -p "Password for $SSID")
    [ -z "$PASS" ] && exit 0

    # Try to connect with password
    nmcli dev wifi connect "$SSID" password "$PASS" >/tmp/rofi-wifi.log 2>&1
    if grep -q "successfully activated" /tmp/rofi-wifi.log; then
        notify-send "WiFi" "Connected to $SSID"
        exit 0
    else
        rofi -theme "$ROFI_THEME" -e "Connection failed! Try again."
    fi
done