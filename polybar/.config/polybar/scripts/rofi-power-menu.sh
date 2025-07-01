#!/bin/bash
# filepath: /home/grace_yudha/code/dotfiles/rofi/.config/rofi/rofi-power-menu.sh

ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"

# Define options
options=" Shutdown\n Restart\n Lock\n Logout"

# Show the menu
chosen=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "Power Menu")

# Function to show confirmation dialog
confirm() {
    echo -e "Yes\nNo" | rofi -dmenu -theme "$ROFI_THEME" -p "Are you sure to $1?"
}

# Function to show confirmation dialog with a timer
confirm_with_timer() {
    local action=$1
    local timer=$TIMER
    while [[ $timer -gt 0 ]]; do
        choice=$(echo -e "Yes\nNo" | rofi -dmenu -theme "$ROFI_THEME" -p "Are you sure to $action? ($timer s)")
        if [[ $choice == "Yes" ]]; then
            echo "Yes"
            return
        elif [[ $choice == "No" ]]; then
            echo "No"
            return
        fi
        ((timer--))
        sleep 1
    done
    echo "Yes"  # Default to "Yes" if timer runs out
}

# Execute the chosen option
case "$chosen" in
    " Shutdown")
        if [[ $(confirm "shutdown") == "Yes" ]]; then
            # xfce4-session-logout --halt
            systemctl poweroff
        fi
        ;;
    " Restart")
        if [[ $(confirm "restart") == "Yes" ]]; then
            # xfce4-session-logout --reboot
            systemctl reboot
        fi
        ;;
    " Lock")
        xflock4
        ;;
    " Logout")
        if [[ $(confirm "logout") == "Yes" ]]; then
            xfce4-session-logout --logout
        fi
        ;;
    *)
        exit 0
        ;;
esac