symlink_file() {
	rm $2
	sudo ln -s $1 $2
	echo "success: symlink created for $1 to $2."
}

install () {
	sudo make install
}


MANJARO_TOOL_PATH=/usr/bin/clear_manjaro_folders
BASHRC_PATH=~/.bashrc
XINITRC_PATH=~/.xinitrc
XSESSION_PATH=/usr/share/xsession/dwm.desktop
REAL_PATH=$( realpath . )

pacman -Sy
bash $REAL_PATH/dependencies/other.sh

symlink_file $REAL_PATH/tools/clear_manjaro_home_folders.sh $MANJARO_TOOL_PATH
sudo cp $REAL_PATH/dwm.desktop $XSESSION_PATH
symlink_file $REAL_PATH/.bashrc $BASHRC_PATH
sudo chmod +x $REAL_PATH/.xinitrc
symlink_file $REAL_PATH/.xinitrc $XINITRC_PATH
symlink_file $REAL_PATH/x.sh /usr/bin/x

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
