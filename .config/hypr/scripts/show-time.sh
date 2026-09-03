#!/bin/bash
# one date call instead of three
IFS='|' read -r TIME DATE WEEK < <(date '+%H:%M|%A, %d. %B %Y|KW %V')
notify-send -a "clock" -u low -t 3000 "$TIME" "$DATE  |  $WEEK"
