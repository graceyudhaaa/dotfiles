#!/bin/bash
dirs=(
  autostart
  bash
  fish
  kitty
  mpv
  picom
  polybar
  rofi
  starship
  sxhkd
  wallpaper
)
for dir in "${dirs[@]}"; do
  stow --target="$HOME" "$dir"
done