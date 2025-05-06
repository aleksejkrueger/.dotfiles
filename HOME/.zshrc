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


if command -v tmux >/dev/null 2>&1; then
	  if [ -z "$TMUX" ] ; then
		      tmux attach-session -t default || tmux new-session -s default
		        fi
fi

export PS1='%/ -> '
