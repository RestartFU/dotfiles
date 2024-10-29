paperview ~/.config/paperview/wallpapers/nord_car/ 10 &
xrandr --output DP-2 --mode 2560x1440 --rate 240
xrandr --output DP-0 --mode 1920x1080 --rate 240 --right-of DP-2 --rotate left
nohup flameshot 2>/dev/null 1>&2 &
xstatus &
chadwm &

while :
do
	~/.tools/pr
	sleep 1000
done
