#      ___           ___           ___
#     /  /\         /  /\         /__/\
#    /  /::|       /  /:/_        \  \:\
#   /  /:/:|      /  /:/ /\        \__\:\
#  /  /:/|:|__   /  /:/ /::\   ___ /  /::\
# /__/:/ |:| /\ /__/:/ /:/\:\ /__/\  /:/\:\
# \__\/  |:|/:/ \  \:\/:/~/:/ \  \:\/:/__\/
#     |  |:/:/   \  \::/ /:/   \  \::/
#     |  |::/     \__\/ /:/     \  \:\
#     |  |:/        /__/:/       \  \:\
#     |__|/         \__\/         \__\/

os=$("$HOME/.dotfiles/src/detect_os")

export HOME="$(echo -n $(bash -c "cd ~${USER} && pwd"))"
export DOTFILES=$HOME/.dotfiles
export CONFIG=$HOME/.config
export DROPBOX=$HOME/Dropbox
export ZDOTDIR=$HOME/.zsh
export VDOTDIR=$CONFIG/nvim
export TDOTDIR=$HOME/.tmux

if [[ "$os" == "osx" ]]; then
    export SUBL=$HOME/Library/Application\ Support/Sublime\ Text
elif [[ "$os" == "linux" || "$os" == "wsl" ]]; then
    export SUBL=$CONFIG\ Support/Sublime\ Text
fi

if [[ "$os" == "wsl" ]]; then
  export windows_username=$(basename $(wslpath $(wslvar USERPROFILE)))
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  export HOMEBREW_CURLRC=1
fi

source $DOTFILES/HOME/.zsh/dracula-zsh-syntax-highlighting/zsh-syntax-highlighting.sh
source $DOTFILES/HOME/.zsh/ohmyzsh/plugins/vi-mode/vi-mode.plugin.zsh
source $DOTFILES/HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $DOTFILES/HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $DOTFILES/HOME/.zsh/zsh-autopair/autopair.zsh
source $DOTFILES/HOME/.zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
source $DOTFILES/HOME/.zsh/powerlevel10k/powerlevel10k.zsh-theme

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.zsh/.p10k.zsh.
[[ ! -f $DOTFILES/HOME/.zsh/.p10k_${os}.zsh ]] || source $DOTFILES/HOME/.zsh/.p10k_${os}.zsh

source $DOTFILES/HOME/.zsh/fzf/shell/completion.zsh
source $DOTFILES/HOME/.zsh/fzf/shell/key-bindings.zsh

# default editor
export EDITOR=nvim

# terminal
export TERM=screen-256color

source $DOTFILES/HOME/.zsh/functions.zsh
source $DOTFILES/HOME/.zsh/ohmyzsh/lib/functions.zsh

# setup a custom completion directory
fpath=($ZDOTDIR/zsh-completions/src $fpath)

# make space between commands
precmd() { print "" }

# zsh history
HISTFILE=$ZDOTDIR/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# enable zmv
autoload zmv

bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line

export GOPATH=$HOME/go
export PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin"
export PATH=:"$PATH:$HOME/Library/Python/3.9/bin"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.dotfiles/.venv/bin/"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
 eval "$(pyenv init -)"
fi

# create / activate venv in $DOTFILES
if [ -d "$HOME/.dotfiles/.venv/" ]; then
    source "$HOME/.dotfiles/.venv/bin/activate"
else
    python3 -m venv "$HOME/.dotfiles/.venv/"
    source "$HOME/.dotfiles/.venv/bin/activate"
fi

# install asdf 
# https://asdf-vm.com/guide/getting-started.html
# git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
 
if [ -f "$HOME/.work/work.zsh" ]; then
    . "$HOME/.asdf/asdf.sh"
fi

# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)

# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

# initalize all completions on $fpath an ignore (-i) all insecure files and directory
compinit -i

if [ -f "$HOME/.work/work.zsh" ]; then
    source "$HOME/.work/work.zsh"
fi

# export AWS_CA_BUNDLE=$HOME/.certificates/all-ca-certs.crt
# export SSL_CERT_FILE=$HOME/.certificates/all-ca-certs.crt
# export REQUESTS_CA_BUNDLE=$HOME/.certificates/all-ca-certs.crt

clear

