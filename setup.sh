symlink_file() {
	rm $2
	ln -s $1 $2
	echo "success: symlink created for $1 to $2."
}

install () {
	sudo make install
}

xdg-settings set default-web-browser librewolf.desktop
sudo pacman -S libxinerama libx11 crystal shards sdl2

BASHRC_PATH=~/.bashrc
XINITRC_PATH=~/.xinitrc
REAL_PATH=$( realpath . )

symlink_file $REAL_PATH/.bashrc $BASHRC_PATH
symlink_file $REAL_PATH/.xinitrc $XINITRC_PATH

# XSTATUS
cd .config/xstatus
shards install
install
cd ../

# SUCKLESS
cd suckless/dwm
install
cd ../dmenu
install
cd ../st
install
cd ../..

# PAPERVIEW
cd paperview
install
cd ../..
