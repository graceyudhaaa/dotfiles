#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/walls"
CURRENT_LINK="$HOME/.config/wallpaper/current"
THEME_FILE="$HOME/.config/rofi/themes/wallpaper-preview.rasi"
NOTIFY_ICON="preferences-desktop-wallpaper"

# Ensure directories exist
mkdir -p "$HOME/.config/wallpaper"
mkdir -p "$WALL_DIR"

# Generate list with image previews
wallpaper=$(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) \
    -printf "%f\n" | sort | while read -r wp; do
        printf "%s\0icon\x1f%s/%s\n" "$wp" "$WALL_DIR" "$wp"
    done | rofi -dmenu \
        -theme "$THEME_FILE" \
        -p "󰸉 Wallpaper")

[ -z "$wallpaper" ] && exit

# Apply wallpaper
ln -sf "$WALL_DIR/$wallpaper" "$CURRENT_LINK"
feh --bg-fill "$CURRENT_LINK"
notify-send -i "$NOTIFY_ICON" "Wallpaper" "Set to $wallpaper"