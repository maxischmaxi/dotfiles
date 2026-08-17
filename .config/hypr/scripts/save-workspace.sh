#!/bin/bash
hyprctl monitors -j | jq -r '.[] | "\(.name) \(.activeWorkspace.id)"' > /tmp/hypr-last-workspaces
hyprctl activeworkspace -j | jq -r '.id' > /tmp/hypr-last-focused-workspace
