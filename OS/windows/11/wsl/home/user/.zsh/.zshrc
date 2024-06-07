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


# End of lines configured by zsh-newuser-install

# check for os type
unameOut="$(uname -s)"

case "${unameOut}" in
    Linux*)     os=linux;;
    Darwin*)    os=osx;;
    CYGWIN*)    os=cygwin;;
    MINGW*)     os=mingw;;
    *)          os="UNKNOWN:${unameOut}"
esac

if [[ "$os" == "osx" || "$os" == "linux" ]]; then
  export HOME="$(echo -n $(bash -c "cd ~${USER} && pwd"))"
fi
export DOTFILES=$HOME/.dotfiles
export CONFIG=$HOME/.config
export DROPBOX=$HOME/Dropbox
export ZDOTDIR=$HOME/.zsh
export VDOTDIR=$CONFIG/nvim
export TDOTDIR=$HOME/.tmux
if [[ "$os" == "osx" ]]; then
    export SUBL=$HOME/Library/Application\ Support/Sublime\ Text
elif [[ "$os" == "linux" ]]; then
    export SUBL=$CONFIG\ Support/Sublime\ Text
fi

source $ZDOTDIR/dracula-zsh-syntax-highlighting/zsh-syntax-highlighting.sh
source $ZDOTDIR/ohmyzsh/plugins/vi-mode/vi-mode.plugin.zsh
source $ZDOTDIR/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZDOTDIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZDOTDIR/zsh-autopair/autopair.zsh
source $ZDOTDIR/ohmyzsh/plugins/web-search/web-search.plugin.zsh
source $DOTFILES/zsh/zsh/variables.zsh

  source $ZDOTDIR/powerlevel10k/powerlevel10k.zsh-theme

  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi

  # To customize prompt, run `p10k configure` or edit ~/.zsh/.p10k.zsh.
  [[ ! -f ~/.zsh/.p10k.zsh ]] || source ~/.zsh/.p10k.zsh


source $HOME/.zsh/fzf/shell/completion.zsh
source $HOME/.zsh/fzf/shell/key-bindings.zsh

# default editor
export EDITOR=nvim

# terminal
export TERM=screen-256color

source $DOTFILES/zsh/zsh/functions.zsh
source $ZDOTDIR/ohmyzsh/lib/functions.zsh
#source $HOME/.zsh/tooling-devops-cli/zsh/tools/gitlab.zsh
#source $HOME/.zsh/tooling-devops-cli/zsh/tools/logging.zsh
#source $HOME/.zsh/tooling-devops-cli/zsh/tools/manage-macos.zsh
#source $HOME/.zsh/tooling-devops-cli/zsh/tools/sop.zsh
#source $HOME/.zsh/tooling-devops-cli/zsh/tools/sops.zsh

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

export PATH="$PATH:$HOME/.local/bin"

#export CURL_CA_BUNDLE=$HOME/mycert.pem
#export SSL_CERT_FILE=$HOME/mycert.pem
#export REQUESTS_CA_BUNDLE=$HOME/mycert.pem
export AWS_CA_BUNDLE=$HOME/.certificates/all-ca-certs.crt

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
 eval "$(pyenv init -)"
fi

# install asdf 
# https://asdf-vm.com/guide/getting-started.html
# git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
. "$HOME/.asdf/asdf.sh"

# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

# enable completion system
autoload compinit

# initalize all completions on $fpath an ignore (-i) all insecure files and directory
compinit -i

cd $HOME
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export HOMEBREW_CURLRC=1

source ${HOME}/.credentials/api_token.zsh
source ${HOME}/.tooling-devops-cli/zsh/main.zsh
GRANTED_ENABLE_AUTO_REASSUME=true
