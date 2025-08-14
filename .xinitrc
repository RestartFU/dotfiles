xset r rate 200 25
xbindkeys 
feh --bg-scale ~/.assets/wallpaper.jpg &
xcompmgr & 
xrandr --output eDP --mode 2880x1920 --rate 120 
nohup flameshot 2>/dev/null 1>&2 &
slstatus &
~/.tools/disable_sleep
dwm
