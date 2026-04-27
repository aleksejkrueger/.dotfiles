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

os="$("$HOME/.dotfiles/src/detect_os")"

export DOTFILES="$HOME/.dotfiles"
export CONFIG="$HOME/.config"
export DROPBOX="$HOME/Dropbox"
export ZDOTDIR="$HOME/.zsh"
export VDOTDIR="$CONFIG/nvim"
export TDOTDIR="$HOME/.tmux"
export NOTES="$HOME/notes/vimwiki"

export EDITOR="nvim"
export VISUAL="$EDITOR"
export TERM="screen-256color"
export GOPATH="$HOME/go"
export PYENV_ROOT="$HOME/.pyenv"
export DOTFILES_VENV="$DOTFILES/.venv"

typeset -U path fpath
path=(
  "$PYENV_ROOT/bin"
  "$HOME/.local/bin"
  "/opt/homebrew/bin"
  "$HOME/Library/Python/3.9/bin"
  "$HOME/.cargo/bin"
  "$GOPATH/bin"
  $path
)

if [[ "$os" == "wsl" ]]; then
  export windows_username="$(basename "$(wslpath "$(wslvar USERPROFILE)")")"

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    export HOMEBREW_CURLRC=1
  fi
fi

if [ -f $(brew --prefix)/etc/brew-wrap ]; then
  source $(brew --prefix)/etc/brew-wrap
fi

autoload -Uz add-zsh-hook zmv compinit

HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY

bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line

source "$DOTFILES/HOME/.zsh/functions.zsh"

export ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR" 2>/dev/null
[[ -d "$ZSH_CACHE_DIR/completions" ]] || mkdir -p "$ZSH_CACHE_DIR/completions" 2>/dev/null

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  source "$ZINIT_HOME/zinit.zsh"

  zinit snippet OMZL::functions.zsh
  zinit snippet OMZP::vi-mode/vi-mode.plugin.zsh
  zinit snippet OMZP::web-search/web-search.plugin.zsh
  zinit snippet OMZP::kubectl/kubectl.plugin.zsh
  zinit snippet OMZP::kubectx/kubectx.plugin.zsh
  zinit snippet OMZP::jira/jira.plugin.zsh

  zinit ice depth=1 pick"zsh-syntax-highlighting.sh"
  zinit light dracula/zsh-syntax-highlighting

  zinit ice depth=1 pick"autopair.zsh"
  zinit light hlissner/zsh-autopair

  zinit ice depth=1
  zinit light zsh-users/zsh-completions

  zinit ice depth=1 pick"fzf-git.sh"
  zinit light junegunn/fzf-git.sh
fi

if [[ -n "${ASDF_DIR:-}" && -d "$ASDF_DIR/completions" ]]; then
  fpath=("$ASDF_DIR/completions" $fpath)
fi

compinit -d "$ZSH_CACHE_DIR/.zcompdump"

if [[ -r "$ZINIT_HOME/zinit.zsh" ]]; then
  zinit ice depth=1 pick"fzf-tab.plugin.zsh"
  zinit light Aloxaf/fzf-tab

  zinit ice depth=1 pick"zsh-autosuggestions.zsh"
  zinit light zsh-users/zsh-autosuggestions

  zinit ice depth=1 pick"zsh-syntax-highlighting.zsh"
  zinit light zsh-users/zsh-syntax-highlighting
fi

if (( $+commands[pyenv] )); then
  eval "$(pyenv init - zsh)"
fi

if [[ -f "$HOME/.work/work.zsh" ]]; then
  source "$HOME/.work/work.zsh"
fi

if (( $+commands[fzf] )) && [[ -t 0 && -t 1 ]]; then
  eval "$(fzf --zsh)"

  export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:-1,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
  export FZF_DEFAULT_COMMAND='fd --hidden --strip-cwd-prefix --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type=d --hidden --strip-cwd-prefix --exclude .git'
  export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

  _fzf_compgen_path() {
    fd --hidden --exclude .git . "$1"
  }

  _fzf_compgen_dir() {
    fd --type=d --hidden --exclude .git . "$1"
  }

  _fzf_comprun() {
    local command="$1"
    shift

    case "$command" in
      cd) fzf --preview "eza --tree --color=always {} | head -200" "$@" ;;
      export|unset) fzf --preview "echo \$${(P)1}" "$@" ;;
      ssh) fzf --preview "dig {}" "$@" ;;
      *) fzf --preview "bat -n --color=always --line-range :500 {}" "$@" ;;
    esac
  }
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

if (( $+commands[starship] )); then
  export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
  eval "$(starship init zsh)"
fi

dots-venv() {
  if [[ ! -d "$DOTFILES_VENV" ]]; then
    python3 -m venv "$DOTFILES_VENV" || return
  fi

  source "$DOTFILES_VENV/bin/activate"
}
