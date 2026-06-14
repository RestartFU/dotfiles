#!/usr/bin/env bash
set -u

OUTPUT="eDP-1"
PLUGGED_HZ="120.00"
BATTERY_HZ="60.00"
RESOLUTION="2880x1920"
POSITION="0x160"
SCALE="1.5"
INTERVAL=5
LOG="/tmp/laptop-refresh-on-power.log"
STATE_FILE="/tmp/laptop-power-mode.state"
FORCE_LOW_POWER_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/laptop-low-power-force"

# Hyprland-only power tweaks.
# Battery = less GPU/compositor work. Plugged = restore normal desktop pretties.
BATTERY_BLUR="false"
PLUGGED_BLUR="true"
BATTERY_VFR="true"
PLUGGED_VFR="false"
BATTERY_VRR="1"
PLUGGED_VRR="0"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

have() { command -v "$1" >/dev/null 2>&1; }

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

apply_monitor() {
  local state="$1" hz="$2" mode line
  mode="$RESOLUTION@$hz"
  line="$(current_line || true)"
  if [[ "$line" != *"$mode"* ]]; then
    log "switching $OUTPUT to $mode ($state); was: ${line:-unknown}; battery=$(battery_status)"
    hyprctl keyword monitor "$OUTPUT,$mode,$POSITION,$SCALE" >> "$LOG" 2>&1 || log "hyprctl monitor failed"
  fi
}

hypr_keyword() {
  local key="$1" value="$2"
  hyprctl keyword "$key" "$value" >> "$LOG" 2>&1 || log "hyprctl keyword $key=$value failed"
}

apply_hypr_power() {
  local state="$1"

  if [[ "$state" == "battery" ]]; then
    # Kill blur and allow variable/VRR presentation when on battery.
    hypr_keyword decoration:blur:enabled "$BATTERY_BLUR"
    hypr_keyword debug:vfr "$BATTERY_VFR"
    hypr_keyword misc:vrr "$BATTERY_VRR"
  else
    # Restore the config's normal AC behavior.
    hypr_keyword decoration:blur:enabled "$PLUGGED_BLUR"
    hypr_keyword debug:vfr "$PLUGGED_VFR"
    hypr_keyword misc:vrr "$PLUGGED_VRR"
  fi
}

apply_optional_system_power() {
  local state="$1"

  # If you install power-profiles-daemon later, this starts working automatically.
  if have powerprofilesctl; then
    if [[ "$state" == "battery" ]]; then
      powerprofilesctl set power-saver >> "$LOG" 2>&1 || log "powerprofilesctl power-saver failed"
    else
      powerprofilesctl set balanced >> "$LOG" 2>&1 || log "powerprofilesctl balanced failed"
    fi
  fi
}

apply_target() {
  local state="$1" hz="$2" old_state=""

  [[ -e "$STATE_FILE" ]] && old_state=$(<"$STATE_FILE")

  apply_monitor "$state" "$hz"

  if [[ "$old_state" != "$state" ]]; then
    log "power mode: ${old_state:-unknown} -> $state"
    apply_hypr_power "$state"
    apply_optional_system_power "$state"
    printf '%s\n' "$state" > "$STATE_FILE"
  fi
}

step() {
  if [[ -e "$FORCE_LOW_POWER_FILE" ]]; then
    apply_target "battery" "$BATTERY_HZ"
  elif is_plugged; then
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
    printf 'force_low_power=%s\n' "$([[ -e "$FORCE_LOW_POWER_FILE" ]] && echo yes || echo no)"
    if [[ -e "$FORCE_LOW_POWER_FILE" ]]; then echo 'decision=battery-forced'; elif is_plugged; then echo 'decision=plugged'; else echo 'decision=battery'; fi
    printf 'monitor=%s\n' "$(current_line || true)"
    printf 'state_file=%s\n' "$(cat "$STATE_FILE" 2>/dev/null || echo none)"
    hyprctl getoption decoration:blur:enabled
    hyprctl getoption debug:vfr
    hyprctl getoption misc:vrr
    ;;
  *)
    log "started pid=$$"
    while true; do
      step
      sleep "$INTERVAL"
    done
    ;;
esac
