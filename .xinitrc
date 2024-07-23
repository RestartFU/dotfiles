MOUSE_ID=$(xinput --list | grep -i -m 1 'logitech usb receiver' | grep -o 'id=[0-9]\+' | grep -o '[0-9]\+')
xrandr --output HDMI-0 --mode 1920x1080 --rate 240
xstatus &
nohup flameshot &
paperview ~/dotfiles/.config/paperview/background 25 &
dwm
