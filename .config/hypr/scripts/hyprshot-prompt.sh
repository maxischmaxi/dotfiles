#!/bin/bash

choice=$(echo -e "Zwischenablage\nSpeichern\nBeides" | rofi -dmenu -p "Screenshot")

case "$choice" in
    "Zwischenablage") hyprshot -m region --clipboard-only ;;
    "Speichern")      hyprshot -m region --freeze ;;
    "Beides")         hyprshot -m region --freeze ;;
esac
