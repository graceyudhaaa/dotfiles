#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/walls"
CURRENT_LINK="$HOME/.config/wallpaper/current"
ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"
NOTIFY_ICON="preferences-desktop-wallpaper"

# Ensure directories exist
mkdir -p "$HOME/.config/wallpaper"
mkdir -p "$WALLPAPER_DIR"

apply_wallpaper() {
    local wallpaper="$1"
    # Update symlink
    ln -sf "$wallpaper" "$CURRENT_LINK"
    # Apply with feh
    feh --bg-fill "$CURRENT_LINK"
    notify-send -i "$NOTIFY_ICON" "Wallpaper" "Set to $(basename "$wallpaper")"
}

# Gather wallpapers (jpg, jpeg, png, webp, bmp)
mapfile -t wallpapers < <(find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
    | sort)

if [ ${#wallpapers[@]} -eq 0 ]; then
    rofi -theme "$ROFI_THEME" -e "No wallpapers found in $WALLPAPER_DIR\n\nDirectory contents:\n$(ls -la "$WALLPAPER_DIR")"
    exit 1
fi

# Get current wallpaper name for marking
current_name=""
if [ -L "$CURRENT_LINK" ]; then
    current_name=$(basename "$(readlink -f "$CURRENT_LINK")")
fi

# Build rofi menu
menu=""
for wp in "${wallpapers[@]}"; do
    name=$(basename "$wp")
    if [ "$name" = "$current_name" ]; then
        menu+="  $name (current)\n"
    else
        menu+="  $name\n"
    fi
done

# Add extra options
menu+="  Random\n  Open wallpaper folder"

selection=$(printf "$menu" | rofi -dmenu -theme "$ROFI_THEME" \
    -p "󰸉 Wallpaper" \
    -mesg "Wallpapers: ${#wallpapers[@]} | Current: ${current_name:-none}")

[ -z "$selection" ] && exit 0

case "$selection" in
    *"Random"*)
        random_wp="${wallpapers[$RANDOM % ${#wallpapers[@]}]}"
        apply_wallpaper "$random_wp"
        ;;
    *"Open wallpaper folder"*)
        xdg-open "$WALLPAPER_DIR" &
        ;;
    *)
        # Extract filename (strip icon and " (current)" suffix)
        chosen=$(echo "$selection" | sed 's/^  //' | sed 's/ (current)$//')
        target="$WALLPAPER_DIR/$chosen"
        if [ -f "$target" ]; then
            apply_wallpaper "$target"
        else
            notify-send -i "$NOTIFY_ICON" "Wallpaper" "File not found: $chosen"
        fi
        ;;
esac