<!-- `make help`

```zsh
make help:
  Available targets:
    @echo "help         - Display this help message"
    @echo "test         - Display detected OS, current directory, and username"
    @echo "setup        - Run the setup process which includes test, scripts, symlinks, alacritty, and os"
    @echo "os           - Perform OS-specific setup tasks (macOS, Linux, or WSL)"
    @echo "scripts      - Make all scripts in the 'scripts' directory executable and symlink them to '/usr/local/bin/'"
    @echo "stow         - Create necessary symlinks by using stow"
    @echo "rust         - Install Rust using rustup"
    @echo "asdf         - Clone the asdf version manager repository"
    @echo "repos        - Clone various Git repositories for data science, cheatsheets, templates, and Pandoc filters"
    @echo "passwords    - Retrieve and set up credentials using pass"
``` -->



## reinstall environment

```
apk add $(cat installed-packages.txt)
```

## clone `.dotfiles`

```
git clone --branch ish --recurse-submodules https://github.com/alexchaichan/.dotfiles.git
cd ~/.dotfiles
git switch ish
git submodule update --init --recursive
git pull --recurse-submodules
```

```
cd /HOME && stow --ignore='\.DS_Store' -t $(HOME) ./
```
<!-- `make setup` -->

