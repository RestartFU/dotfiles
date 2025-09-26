if [[ "$ENV" == "laptop" ]] then
	xrandr --output eDP --mode 2880x1920 --rate 120
	if [[ "$MODE" == "monitor" ]] then
		xrandr --output DisplayPort-3 --mode 2560x1440 --rate 240 --left-of eDP
		xrandr --output DisplayPort-2 --mode 2560x1440 --rate 240 --left-of eDP
		xrandr --output DisplayPort-1 --mode 2560x1440 --rate 240 --left-of eDP
		ENV=desktop
	fi
elif [[ "$ENV" == "desktop" ]] then
	#TODO
#	FIREFOX_ZOOM=1
	echo ""
else
	echo "invalid environment"
	exit 1
fi

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
feh --bg-fill ~/.config/wallpapers/wallpaper1.jpg

# Transparent Terminal
xcompmgr -c &

# Enable flameshot to copy to clipboard
nohup flameshot 2>/dev/null 1>&2 &

sleep 10
bluetoothctl connect F8:73:DF:1F:4B:63

sleep infinity
