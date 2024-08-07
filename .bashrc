#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return
export QT_QPA_PLATFORMTHEME=xfce

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias pacman='sudo pacman'
alias aur='pamac build'
alias shutdown='shutdown now'
alias goland='goland . & disown && exit'

# Exports
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/usr/local/v

# goto is a function used to 'cd' into specific directories quicker
function goto(){
	if [ $# -ne 1 ]; then
	    echo "not enough arguments were provided"
	    return
	fi

	case $1 in
	    dwm)
		cd "$HOME/dotfiles/.config/suckless/dwm"
		;;
	    dmenu)
		cd "$HOME/dotfiles/.config/suckless/dmenu"
		;;
	    st)
		cd "$HOME/dotfiles/.config/suckless/st"
		;;
	    slstatus)
		cd "$HOME/dotfiles/.config/suckless/slstatus"
		;;
	esac
}

PS1='[\u@\h \W]\$ '

bash clear_manjaro_folders
