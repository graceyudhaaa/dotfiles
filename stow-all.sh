#!/bin/bash
for dir in fish sxhkd rofi polybar mpv starship; do
  stow --target="$HOME" "$dir"
done