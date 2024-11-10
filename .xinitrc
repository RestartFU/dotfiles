paperview ~/.config/paperview/wallpapers/nord_car/ 10 &
xrandr --output eDP --mode 2880x1920 --rate 120
#xrandr --output DP-0 --mode 1920x1080 --rate 240 --right-of DP-2 --rotate left
nohup flameshot 2>/dev/null 1>&2 &
xstatus &
dwm &

while :
do
	cd ~ && ~/.tools/pr
	sleep 1000
done
