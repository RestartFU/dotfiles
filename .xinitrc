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
cd ~

~/.config/dwm/dwm &
~/.tools/disable_sleep

sleep infinity
