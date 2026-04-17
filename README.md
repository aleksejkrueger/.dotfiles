`just help`

```zsh
just help
  Available recipes:
    help         - Display this help message.
    test         - Display detected OS, current directory, and username.
    setup        - Run the setup process which includes test, scripts, stow, and os.
    os [device]  - Perform OS-specific setup tasks (macOS, Linux, or WSL).
    scripts      - Make all scripts in src executable and symlink them to /usr/local/bin/.
    stow         - Create necessary symlinks by using stow.
    rust         - Install Rust using rustup.
    asdf         - Clone the asdf version manager repository.
    repos        - Clone various Git repositories for data science, cheatsheets, templates, and Pandoc filters.
    passwords    - Retrieve and set up credentials using pass.
```

## package manager

```
if [[ "$(uname)" == "Darwin" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
  sudo apt update
fi
```

## git & just

```
if [[ "$(uname)" == "Darwin" ]]; then
    brew install git just
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
    sudo apt install git just
fi
```

## clone `.dotfiles`

```
git clone https://github.com/aleksejkrueger/.dotfiles.git
cd ~/.dotfiles
git pull
```

The zsh plugin stack is bootstrapped by `zinit` from `HOME/.zshrc` on first shell start, so no zsh submodule init step is needed anymore.

Tmux plugins are bootstrapped by TPM from [`HOME/.tmux.conf`](/Users/aleksej.chaichan/.dotfiles/HOME/.tmux.conf). After `just setup` or `just stow`, install TPM if needed with `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`, then inside tmux press `prefix + I`.

## store [`.password-store`](https://github.com/aleksejkrueger/.password-store/archive/refs/heads/main.zip) into `~/`

`mv ~/Downloads/password-store-main/.password-store-main/ ~/.password-store/`

## store [`.gnupg`](https://drive.proton.me/urls/1K1QVY03ZC#8nRtoDHTIi6J) into `~/`

```
unzip ~/Downloads/gnupg.zip -d ~/Downloads/ && mv ~/Downloads/gnupg ~/.gnupg
```

## store [`.ssh`](https://drive.proton.me/urls/ZMK4QJ66H4#OTp4ouSzq31D) into `~/`

```
unzip ~/Downloads/ssh.zip -d ~/Downloads/ && mv ~/Downloads/ssh ~/.ssh
```

## run installation file

`just setup`
