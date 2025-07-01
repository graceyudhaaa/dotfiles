#!/bin/bash
# filepath: /home/grace_yudha/code/dotfiles/rofi/.config/rofi/rofi-power-menu.sh

ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"

# Define options
options=" Shutdown\n Restart\n Lock\n Logout"

# Show the menu
chosen=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "Power Menu")

# Execute the chosen option
case "$chosen" in
    " Shutdown")
        # xfce4-session-logout --halt
        systemctl poweroff
        ;;
    " Restart")
        # xfce4-session-logout --reboot
        systemctl reboot
        ;;
    " Lock")
        xflock4
        ;;
    " Logout")
        xfce4-session-logout --logout
        # pkill -KILL -u "$USER"
        ;;
    *)
        exit 0
        ;;
esac