#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias gi='~/.tools/gitinclude'
PS1='[\u@\h \W]\$ '
