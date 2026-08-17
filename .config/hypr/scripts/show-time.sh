#!/bin/bash
TIME=$(date '+%H:%M')
DATE=$(date '+%A, %d. %B %Y')
WEEK=$(date '+KW %V')
notify-send -a "clock" -u low -t 3000 "$TIME" "$DATE  |  $WEEK"
