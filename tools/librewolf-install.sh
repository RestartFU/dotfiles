sudo pacman -S make gcc

gpg --receive-keys 8a74eaaf89c17944

git clone https://aur.archlinux.org/librewolf-bin.git
cd librewolf-bin
makepkg -si
cd ..
rm -rf librewolf-bin

xdg-settings set default-web-browser librewolf.desktop
