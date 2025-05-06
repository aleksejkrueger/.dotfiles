os=$("$HOME/.dotfiles/src/detect_os")
export HOME="$(echo -n $(bash -c "cd ~${USER} && pwd"))"
export DOTFILES=$HOME/.dotfiles
export CONFIG=$HOME/.config
export ZDOTDIR=$HOME/.zsh
export VDOTDIR=$CONFIG/nvim
export TDOTDIR=$HOME/.tmux

export PATH="$PATH:$HOME/.cargo/bin"

export EDITOR=nvim
export VISUAL=nvim
HISTFILE=$HOME/.zsh/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

source $HOME/.zsh/dracula-zsh-syntax-highlighting/zsh-syntax-highlighting.sh
source $HOME/.zsh/ohmyzsh/plugins/vi-mode/vi-mode.plugin.zsh
source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOME/.zsh/zsh-autopair/autopair.zsh

export GPG_TTY=$(tty)

source $DOTFILES/HOME/.zsh/functions.zsh
source $DOTFILES/HOME/.zsh/ohmyzsh/lib/functions.zsh

# make space between commands
precmd() { print "" }

# enable zmv
autoload zmv

bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line

# fzf
eval "$(fzf --zsh)"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

source $HOME/.zsh/fzf-git.sh/fzf-git.sh

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

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'

# setup a custom completion directory
fpath=($ZDOTDIR/zsh-completions/src $fpath)

# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit




# zoxide
eval "$(zoxide init zsh)"


if command -v tmux >/dev/null 2>&1; then
	  if [ -z "$TMUX" ] ; then
		      tmux attach-session -t default || tmux new-session -s default
		        fi
fi

export PS1='%/ -> '
