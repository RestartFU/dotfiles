#auto_update &
xrandr --output HDMI-0 --mode 1920x1080 --rate 240
xstatus &
nohup flameshot 2>/dev/null 1>&2 &
paperview ~/dotfiles/.config/paperview/background_snow_house 10 &
dwm &
pulseaudio &
arti proxy &

sleep infinity
