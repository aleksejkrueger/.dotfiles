set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

help:
  @printf '%s\n' \
    'Available recipes:' \
    '  help         - Display this help message.' \
    '  test         - Display detected OS, current directory, and username.' \
    '  setup        - Run the setup process which includes test, scripts, stow, and os.' \
    '  os [device]  - Perform OS-specific setup tasks (macOS, Linux, or WSL).' \
    '  scripts      - Make all scripts in src executable and symlink them to /usr/local/bin/.' \
    '  stow         - Create necessary symlinks by using stow.' \
    '  rust         - Install Rust using rustup.' \
    '  asdf         - Clone the asdf version manager repository.' \
    '  repos        - Clone various Git repositories for data science, cheatsheets, templates, and Pandoc filters.' \
    '  passwords    - Retrieve and set up credentials using pass.'

test:
  @os="$(if [[ "${OS:-}" == "Windows_NT" ]]; then echo windows; else src/detect_os; fi)"; \
  cur_dir="$(pwd)"; \
  username="$(whoami)"; \
  printf 'OS = %s\nCUR_DIR = %s\nUSERNAME = %s\n' "$os" "$cur_dir" "$username"

setup device='':
  @just test
  @just scripts
  @just stow
  @just os "{{device}}"
  @echo 'finished'

scripts:
  chmod +x "$(pwd)"/src/*; \
  sudo ln -sf "$(pwd)"/src/* /usr/local/bin/

stow:
  cd "$(pwd)"/HOME && stow --ignore='\.DS_Store' -t "$HOME" ./

os device='':
  @device='{{device}}'; \
  if [[ -z "$device" ]]; then \
    read -r -p 'Choose an option (work/private): ' device; \
  fi; \
  os="$(if [[ "${OS:-}" == "Windows_NT" ]]; then echo windows; else src/detect_os; fi)"; \
  export DEVICE="$device"; \
  if [[ "$os" == 'osx' ]]; then \
    echo "$os detected"; \
    echo 'run .macos'; \
    sudo -v; \
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & \
    bash -c "source $(pwd)/OS/osx/.macos"; \
    echo 'install Brewfile'; \
    brew tap rcmdnk/file; \
    brew install brew-file; \
    if [ -f $(brew --prefix)/etc/brew-wrap ]; then \
      source $(brew --prefix)/etc/brew-wrap \
    fi;\
    brew file install; \
    echo 'source duti-file'; \
    bash -c "source $(pwd)/OS/osx/duti.sh"; \
    mkdir -p "$HOME/.qutebrowser"; \
    ln -sf "$HOME/.dotfiles/HOME/.config/qutebrowser/"* "$HOME/.qutebrowser/"; \
  elif [[ "$os" == 'linux' ]]; then \
    echo "$os detected"; \
  elif [[ "$os" == 'wsl' ]]; then \
    echo "$os detected"; \
    echo 'install packages'; \
    sudo apt install -y zsh procps curl file git tmux ranger; \
    echo 'install linuxbrew'; \
    /bin/bash -c "$(curl --no-keepalive -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"; \
  fi; \
  if [[ -z "$($SHELL -lc 'printf %s "${ZSH_VERSION:-}"')" ]]; then \
    zsh_path="$(command -v zsh)"; \
    sudo sh -c "printf '%s\n' '$zsh_path' >> /etc/shells"; \
    chsh -s "$zsh_path"; \
  fi

rust:
  @echo 'rust-up'; \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

asdf:
  git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.14.0

repos:
  git clone https://github.com/aleksejkrueger/data-science.git "$HOME/data-science"; \
  git clone https://github.com/aleksejkrueger/cheatsheets.git "$HOME/cheatsheets"; \
  git clone https://github.com/aleksejkrueger/Templates.git "$HOME/Templates"; \
  git clone https://github.com/pandoc/lua-filters.git "$HOME/.local/share/pandoc/filters"

passwords:
  mkdir -p "$HOME/.config/spotify-tui" "$HOME/.cache/spotifyd"; \
  printf '\n' | pass spotify/spotify-tui > "$HOME/.config/spotify-tui/client.yml"; \
  printf '\n' | pass spotify/spotifyd > "$HOME/.cache/spotifyd/credentials.json"
