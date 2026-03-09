#!/usr/bin/env bash

status=$(playerctl status 2>/dev/null)

case "$status" in
    "Playing") echo "󰏤" ;;
    "Paused")  echo "󰐊" ;;
    *)         echo "󰐊" ;;
esac