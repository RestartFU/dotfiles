#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

term="$(cat /proc/$PPID/comm)"
if [[ $term = "st" ]]; then
    transset "0.8" --id "$WINDOWID"  > /dev/null
fi

export PATH=$HOME/.local/bin:$PATH
export PATH="$HOME/go/bin:$PATH"

alias cpy='xclip -selection clipboard'
alias frequent_startx='MODE=monitor ENV=laptop startx'
alias headset='bluetoothctl connect F8:73:DF:1F:4B:63'
alias ls='ls --color=auto'
alias dyn='sudo dyn'
alias grep='grep --color=auto'
alias gi='~/.tools/gitinclude'
alias udf='git commit -m "CHANGES" && git push'
alias pacman='sudo pacman'
alias cargo='CARGO_NET_GIT_FETCH_WITH_CLI=true cargo'
alias reboot='sudo reboot'

PS1='\[\e[38;5;214m\]re\[\e[38;5;208m\]st\[\e[38;5;202m\]art\[\e[0m\] \[\e[38;5;39m\]\w\[\e[0m\] \[\e[38;5;220m\]➜\[\e[0m\] '
