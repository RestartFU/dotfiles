xrandr --output eDP --mode 2880x1920 --rate 120
xrandr --output DisplayPort-1 --mode 2560x1440 --rate 240 --left-of eDP

brightnessctl set $(cat ${HOME}/.brightness)

ENV=laptop
cd ~/.config/dwm
./make.sh
cd ~/.config/st
./make.sh
cd ~/.config/slstatus
./make.sh
cd ~

~/.config//slstatus/slstatus &
~/.config/dwm/dwm &
~/.tools/disable_sleep
xbindkeys
dunst &

paperview ~/.config/wallpapers/gif/water/ 15 0 0 2560 1440 \
          ~/.config/wallpapers/gif/water/ 15 2560 0 2880 1920 &

# Transparent Terminal
#xcompmgr -c &

# Enable flameshot to copy to clipboard
nohup flameshot 2>/dev/null 1>&2 &

pipewire &
pipewire-pulse &
wireplumber &

sleep 10
bluetoothctl connect F8:73:DF:1F:4B:63

sleep infinity
