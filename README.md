`make help`

```zsh
help:
        @echo "Available targets:"
        @echo "  help         - Display this help message."
        @echo "  test         - Display detected OS, current directory, and username."
        @echo "  setup        - Run the setup process which includes test, scripts, symlinks, alacritty, and os."
        @echo "  os           - Perform OS-specific setup tasks (macOS, Linux, or WSL)."
        @echo "  scripts      - Make all scripts in the 'scripts' directory executable and symlink them to '/usr/local/bin/'."
        @echo "  symlinks     - Create necessary symlinks by running the 'scripts/symlinks' script."
        @echo "  alacritty    - Setup Alacritty configuration based on the detected OS."
        @echo "  subl         - Initialize Sublime Text configuration."
        @echo "  rust         - Install Rust using rustup."
        @echo "  asdf         - Clone the asdf version manager repository."
        @echo "  python       - Install pyenv and set the global Python version to 3.11.6."
        @echo "  repos        - Clone various Git repositories for data science, cheatsheets, templates, and Pandoc filters."
        @echo "  passwords    - Retrieve and set up credentials using pass."
```

## package manager

```
if [[ "$(uname)" == "Darwin" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
  sudo apt update
fi
```

## git & make

```
if [[ "$(uname)" == "Darwin" ]]; then
    brew install git make
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
    sudo apt install git build-essential
fi
```

## clone `.dotfiles`

```
git clone --recurse-submodules https://github.com/alexchaichan/.dotfiles.git
cd ~/.dotfiles
git submodule update --init --recursive
git pull --recurse-submodules
```

## store [`.password-store`](https://github.com/alexchaichan/.password-store/archive/refs/heads/main.zip) into `~/`

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

`make setup`

