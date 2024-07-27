folders=("Public" "Desktop" "Documents" "Downloads" "Music" "Pictures" "Templates" "Videos")
for key in "${!folders[@]}"
do
	rm -rf "/home/${USER}/${folders[key]}"
done
