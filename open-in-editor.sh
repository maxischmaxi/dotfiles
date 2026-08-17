#!/bin/bash
# Opens a file in neovim, optionally at a specific line
# Usage: open-in-editor.sh editor://path/to/file:line:col
#    or: open-in-editor.sh editor:///absolute/path:line

uri="$1"

# Remove editor:// prefix
path="${uri#editor://}"

# Extract line number if present (format: path:line or path:line:col)
if [[ "$path" =~ ^(.+):([0-9]+)(:([0-9]+))?$ ]]; then
    file="${BASH_REMATCH[1]}"
    line="${BASH_REMATCH[2]}"
    col="${BASH_REMATCH[4]:-1}"
else
    file="$path"
    line=1
    col=1
fi

# Handle relative paths - try current working directory patterns
if [[ ! "$file" = /* ]]; then
    # Try to find the file in common locations
    if [[ -f "$file" ]]; then
        file="$(pwd)/$file"
    elif [[ -f "$HOME/$file" ]]; then
        file="$HOME/$file"
    fi
fi

# Open in neovim in a new terminal
wezterm start -- nvim "+call cursor($line, $col)" "$file"
