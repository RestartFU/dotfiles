#!/usr/bin/env bash
set -euo pipefail

direction=${1:?usage: workspace-gesture.sh <next|prev>}

case "$direction" in
  next) target=e+1 ;;
  prev) target=e-1 ;;
  *)
    printf 'usage: %s <next|prev>\n' "${0##*/}" >&2
    exit 64
    ;;
esac

if command -v jq >/dev/null 2>&1; then
  occupied_count=$(
    hyprctl workspaces -j 2>/dev/null \
      | jq '[.[] | select((.id // 0) > 0 and (.windows // 0) > 0)] | length' 2>/dev/null \
      || printf '0'
  )

  if [ "$occupied_count" = "2" ]; then
    case "$direction" in
      next) target=e-1 ;;
      prev) target=e+1 ;;
    esac
  fi
fi

hyprctl dispatch workspace "$target" >/dev/null
