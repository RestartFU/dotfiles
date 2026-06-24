#!/usr/bin/env sh
set -eu

target="${1:?usage: workspace-noanim.sh <workspace>}"

restore() {
    hyprctl keyword animation "workspaces,1,12,easeOutQuint,slide" > /dev/null
    hyprctl keyword animation "workspacesIn,1,10,easeOutQuint,slide" > /dev/null
    hyprctl keyword animation "workspacesOut,1,10,easeOutQuint,slide" > /dev/null
}

trap restore EXIT HUP INT TERM

hyprctl keyword animation "workspaces,0,12,easeOutQuint,slide" > /dev/null
hyprctl keyword animation "workspacesIn,0,10,easeOutQuint,slide" > /dev/null
hyprctl keyword animation "workspacesOut,0,10,easeOutQuint,slide" > /dev/null

hyprctl dispatch workspace "$target" > /dev/null
sleep 0.08
