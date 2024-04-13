symlink_file() {
	rm $2
	ln -s $1 $2
	echo "success: symlink created for $1 to $2."
}

install () {
	sudo make install
}

sudo pacman -S libxinemara libx11 crystal shards sdl2

BASHRC_PATH=~/.bashrc
XINITRC_PATH=~/.xinitrc

symlink_file .bashrc $BASHRC_PATH
symlink_file .xinitrc $XINITRC_PATH

# XSTATUS
cd .config/xstatus
shards install
sudo make install
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
