#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

term="$(cat /proc/$PPID/comm)"
if [[ $term = "st" ]]; then
    transset-df "0.8" --id "$WINDOWID"  >⋗ /dev/null
fi

export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/29.0.14033849


alias androidcli='/opt/android-studio/bin/studio.sh'
alias frequent_startx='MODE=monitor ENV=laptop startx'

alias tree='tree -I "node_modules|dist|.git" | xclip -selection clipboard'
alias headset='bluetoothctl connect F8:73:DF:1F:4B:63'
alias ls='ls --color=auto'
alias dyn='sudo dyn'
alias grep='grep --color=auto'
alias gi='~/.tools/gitinclude'
alias udf='git commit -m "CHANGES" && git push'
alias pacman='sudo pacman --noconfirm'
alias cargo='CARGO_NET_GIT_FETCH_WITH_CLI=true cargo'
PS1='[\u@\h \W]\$ '
export PATH=$HOME/.local/bin:$PATH
export PATH="$HOME/go/bin:$PATH"
. "$HOME/.cargo/env"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools
export ANDROID_NDK_ROOT=/opt/android-ndk-r25c
export PATH=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
export PATH="$HOME/flutter/bin:$PATH"
