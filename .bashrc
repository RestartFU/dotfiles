#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

alias getcwd='cd; cd -'
alias watch='watch --color'
alias pacman='sudo pacman --noconfirm'

#function cf() {
	#if [ $1 == "down" ]; then
	#	wg-quick down wgcf-profile
	#elif [ $1 == "up" ]; then
	#	wg-quick up wgcf-profile
	#fi
#}

PS1='[\u@\h \W]\$ '
