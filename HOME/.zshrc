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
# export SUBLIME_TEXT_CONFIG_DIR=/$CONFIG/sublime-text
export NOTES=$HOME/notes/vimwiki

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
source $DOTFILES/HOME/.zsh/ohmyzsh/plugins/kube-ps1/kube-ps1.plugin.zsh
source $DOTFILES/HOME/.zsh/ohmyzsh/plugins/kubectl/kubectl.plugin.zsh
source $DOTFILES/HOME/.zsh/ohmyzsh/plugins/kubectx/kubectx.plugin.zsh
source $DOTFILES/HOME/.zsh/fzf-tab/fzf-tab.plugin.zsh
source $DOTFILES/HOME/.zsh/fzf-git.sh/fzf-git.sh

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.zsh/.p10k.zsh.
[[ ! -f $DOTFILES/HOME/.zsh/.p10k_${os}.zsh ]] || source $DOTFILES/HOME/.zsh/.p10k_${os}.zsh

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
 
# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)

# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

# initalize all completions on $fpath an ignore (-i) all insecure files and directory
compinit -i


if [ -f "$HOME/.work/work.zsh" ]; then

    source "$HOME/.work/work.zsh"

fi

# fzf
eval "$(fzf --zsh)"

export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:-1,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6,spinner:#ffb86c,header:#6272a4'

## old keybindings
# source $DOTFILES/HOME/.zsh/fzf/shell/completion.zsh
# source $DOTFILES/HOME/.zsh/fzf/shell/key-bindings.zsh

# fd instead fzf
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)             fzf --preview "eza --tree --color=always {} | head -200" "$@" ;;
    export|unset)   fzf --preview "echo \$${(P)1}" "$@" ;;  # Assume $1 is used as variable name
    ssh)            fzf --preview "dig {}" "$@" ;;
    *)              fzf --preview "bat -n --color=always --line-range :500 {}" "$@" ;;
  esac
}

# zoxide
eval "$(zoxide init zsh)"

# export AWS_CA_BUNDLE=$HOME/.certificates/all-ca-certs.crt
# export SSL_CERT_FILE=$HOME/.certificates/all-ca-certs.crt
# export REQUESTS_CA_BUNDLE=$HOME/.certificates/all-ca-certs.crt

clear

source "/opt/homebrew/opt/kube-ps1/share/kube-ps1.sh"
PS1='$(kube_ps1)'$PS1

# PROMPT='$(kube_ps1)'$PROMPT # or RPROMPT='$(kube_ps1)'

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

