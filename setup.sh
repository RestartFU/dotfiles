symlink_file() {
	rm $2
	ln -s $1 $2
	echo "success: symlink created for $1 to $2."
}

sudo pacman -S libxinemara libx11 crystal shards sdl2

BASHRC_PATH=~/.bashrc
XINITRC_PATH=~/.xinitrc

symlink_file .bashrc $BASHRC_PATH
symlink_file .xinitrc $XINITRC_PATH
