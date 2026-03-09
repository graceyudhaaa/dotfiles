#!/usr/bin/env bash

artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)

if [ -n "$artist" ] && [ -n "$title" ]; then
    text="$artist - $title"
    # Truncate if too long
    if [ ${#text} -gt 40 ]; then
        text="${text:0:37}..."
    fi
    echo "$text"
else
    echo ""
fi