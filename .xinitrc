if [[ "$ENV" == "laptop" ]] then
	xrandr --output eDP-1 --mode 2880x1920 --rate 120
elif [[ "$ENV" == "desktop" ]] then
	#TODO
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

sleep infinity
