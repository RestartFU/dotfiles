#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

term="$(cat /proc/$PPID/comm)"
if [[ $term = "st" ]]; then
    transset-df "0.8" --id "$WINDOWID"  >⋗ /dev/null
fi

alias headset='bluetoothctl connect F8:73:DF:1F:4B:63'
alias ls='ls --color=auto'
alias dyn='sudo dyn'
alias grep='grep --color=auto'
alias gi='~/.tools/gitinclude'
alias udf='git commit -m "CHANGES" && git push'
alias pacman='sudo pacman --noconfirm'
PS1='[\u@\h \W]\$ '
export PATH=$HOME/.local/bin:$PATH
