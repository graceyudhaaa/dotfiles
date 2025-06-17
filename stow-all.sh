#!/bin/bash
dirs=(
  fish
  sxhkd
  rofi
  polybar
  mpv
  starship
  autostart
  picom
  kitty
)
for dir in "${dirs[@]}"; do
  stow --target="$HOME" "$dir"
done