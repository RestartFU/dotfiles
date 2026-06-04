#!/usr/bin/env bash
set -u

OUTPUT="eDP-1"
PLUGGED_HZ="120.00"
BATTERY_HZ="60.00"
RESOLUTION="2880x1920"
POSITION="0x1440"
SCALE="1.5"
INTERVAL=5
LOG="/tmp/laptop-refresh-on-power.log"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

ac_online() {
  local ps type online
  for ps in /sys/class/power_supply/*; do
    [[ -e "$ps/type" ]] || continue
    type=$(<"$ps/type")
    if [[ "$type" == "Mains" && -e "$ps/online" ]]; then
      online=$(<"$ps/online")
      [[ "$online" == "1" ]] && return 0
    fi
  done
  return 1
}

battery_status() {
  local ps type
  for ps in /sys/class/power_supply/*; do
    [[ -e "$ps/type" && -e "$ps/status" ]] || continue
    type=$(<"$ps/type")
    if [[ "$type" == "Battery" ]]; then
      cat "$ps/status"
      return 0
    fi
  done
  echo unknown
}

is_plugged() {
  local st
  if ac_online; then
    return 0
  fi
  # Fallback only if no AC adapter is exposed.
  st=$(battery_status)
  [[ "$st" == "Charging" || "$st" == "Full" || "$st" == "Not charging" ]]
}

current_line() {
  hyprctl monitors all | awk -v out="$OUTPUT" '
    $0 ~ "Monitor " out {p=1; next}
    p && /^Monitor / {exit}
    p && /^[[:space:]]*[0-9]+x[0-9]+@/ {gsub(/^[[:space:]]+/, ""); print; exit}
  '
}

apply_target() {
  local state="$1" hz="$2" mode line
  mode="$RESOLUTION@$hz"
  line="$(current_line || true)"
  if [[ "$line" != *"$mode"* ]]; then
    log "switching $OUTPUT to $mode ($state); was: ${line:-unknown}; battery=$(battery_status)"
    hyprctl keyword monitor "$OUTPUT,$mode,$POSITION,$SCALE" >> "$LOG" 2>&1 || log "hyprctl failed"
  fi
}

step() {
  if is_plugged; then
    apply_target "plugged" "$PLUGGED_HZ"
  else
    apply_target "battery" "$BATTERY_HZ"
  fi
}

case "${1:-}" in
  --once)
    step
    ;;
  --debug)
    printf 'battery_status=%s\n' "$(battery_status)"
    if is_plugged; then echo 'decision=plugged'; else echo 'decision=battery'; fi
    printf 'monitor=%s\n' "$(current_line || true)"
    ;;
  *)
    log "started pid=$$"
    while true; do
      step
      sleep "$INTERVAL"
    done
    ;;
esac
