#!/usr/bin/env bash
set -euo pipefail

# Install Arch Linux requirements for this Hyprland rice.
# Covers the tracked configs in ~/.gitinclude:
#   ~/.config/hypr, waybar, fuzzel, waypaper, swayosd, alacritty, nvim, zed
# Run with: bash ~/requiements/arch.sh

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Run this as your normal user; the script will call sudo when needed." >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman not found; this installer is for Arch Linux." >&2
  exit 1
fi

sudo -v

packages=(
  # Hyprland session + portals
  hyprland
  hypridle
  hyprlock
  xdg-desktop-portal
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  polkit
  polkit-kde-agent
  qt5-wayland
  qt6-wayland

  # Bar, launcher, terminal, browser
  waybar
  fuzzel
  alacritty
  firefox

  # Wallpaper stack
  waypaper
  awww

  # mac-like media/brightness OSD
  swayosd
  brightnessctl

  # Audio/media controls used by Hyprland + Waybar
  pipewire
  pipewire-alsa
  pipewire-pulse
  wireplumber
  pavucontrol
  libpulse
  playerctl

  # Screenshots + clipboard
  grim
  slurp
  flameshot
  wl-clipboard

  # Notifications used by Waybar battery events
  libnotify
  mako

  # Network module / common tray utility
  networkmanager
  network-manager-applet

  # Theme/settings helpers used by config startup lines
  glib2
  gsettings-desktop-schemas
  dbus
  xdg-utils

  # Fonts/icons for Waybar glyphs and general UI
  noto-fonts
  noto-fonts-emoji
  ttf-jetbrains-mono-nerd
  ttf-nerd-fonts-symbols

  # Editors/dev tools tracked in this rice
  neovim
  zed
)

# Drop packages not available in enabled repos, instead of failing the whole install
# on machines without extra/community/AUR-style repo additions.
available=()
missing=()
for pkg in "${packages[@]}"; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    available+=("$pkg")
  else
    missing+=("$pkg")
  fi
done

if ((${#available[@]})); then
  sudo pacman -Syu --needed --noconfirm "${available[@]}"
fi

if ((${#missing[@]})); then
  echo "Skipped packages not found in enabled pacman repos:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  if command -v yay >/dev/null 2>&1; then
    echo "Trying skipped packages with yay..." >&2
    yay -S --needed --noconfirm "${missing[@]}" || true
  fi
fi

# Enable common services. These are idempotent and non-fatal for systems that
# intentionally manage services another way.
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 || true
sudo systemctl enable --now NetworkManager.service >/dev/null 2>&1 || true

# SwayOSD ships udev/polkit integration. Reload udev so brightness/media OSD
# permissions are available without waiting for reboot.
sudo udevadm control --reload-rules >/dev/null 2>&1 || true
sudo udevadm trigger >/dev/null 2>&1 || true

cat <<'MSG'

Rice requirements installed.

Recommended after first install:
  1. Log out/in, or reboot, so user services/groups/udev permissions refresh.
  2. Start Hyprland.
  3. If battery notify-send events need visible popups, autostart mako or another notification daemon.

Main runtime commands this rice expects:
  hyprland waybar fuzzel alacritty firefox waypaper awww-daemon
  swayosd-server swayosd-client brightnessctl wpctl pactl playerctl
  grim slurp flameshot wl-copy notify-send
MSG
