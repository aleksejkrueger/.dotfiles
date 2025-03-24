.PHONY: help
help:
	@echo "Available targets:"
	@echo "  help         - Display this help message."
	@echo "  test         - Display detected OS, current directory, and username."
	@echo "  setup        - Run the setup process which includes test, scripts, symlinks, alacritty, and os."
	@echo "  os           - Perform OS-specific setup tasks (macOS, Linux, or WSL)."
	@echo "  scripts      - Make all scripts in the 'scripts' directory executable and symlink them to '/usr/local/bin/'."
	@echo "  symlinks     - Create necessary symlinks by running the 'src/symlinks' script."
	@echo "  alacritty    - Setup Alacritty configuration based on the detected OS."
	@echo "  subl         - Initialize Sublime Text configuration."
	@echo "  rust         - Install Rust using rustup."
	@echo "  asdf         - Clone the asdf version manager repository."
	@echo "  repos        - Clone various Git repositories for data science, cheatsheets, templates, and Pandoc filters."
	@echo "  passwords    - Retrieve and set up credentials using pass."

# Detect the operating system
ifeq ($(OS),Windows_NT)
    OS := windows
else
    OS := $(shell src/detect_os)
endif

CUR_DIR := $(shell pwd)
USERNMAE := $(shell whoami)

.PHONY: test
test:
	@echo 'OS = $(OS)'
	@echo 'CUR_DIR = $(CUR_DIR)'
	@echo 'USERNMAE = $(USERNMAE)'

.PHONY: setup
setup: test scripts symlinks os
	@echo "fnished"

.PHONY: scripts
scripts:
	chmod +x $(CUR_DIR)/src/*; \
	sudo ln -sf $(CUR_DIR)/src/* /usr/local/bin/;

.PHONY: symlinks
symlinks: alacritty subl
	$(shell src/symlinks)

.PHONY: alacritty
alacritty:
	@if [ "$(OS)" = "osx" ]; then \
		ln -sf $(HOME)/.dotfiles/alacritty/alacritty_osx.toml $(HOME)/.config/alacritty.toml; \
		mkdir -p $(HOME)/.alacritty; \
	elif [ "$(OS)" = "linux" ]; then \
		echo " "; \
	elif [ "$(OS)" = "wsl" ]; then \
		export windows_username=$(basename $(wslpath $(wslvar USERPROFILE))); \
		cp -f $(HOME)/.dotfiles/alacritty/alacritty_wsl.toml /mnt/c/Users/$(windows_username)/AppData/Roaming/alacritty/alacritty.toml; \
	fi

.PHONY: subl
subl:
	@if [ "$(OS)" = "osx" ]; then \
		echo "init sublime text"; \
			mkdir -p $(HOME)/Library/Application\ Support/Sublime\ Text/; \
			mkdir -p $(HOME)/Library/Application\ Support/Sublime\ Text/Packages/; \
			mkdir -p $(HOME)/Library/Application\ Support/Sublime\ Text/Packages/User/; \
			sudo ln -sf $(CUR_DIR)/HOME/.config/sublime-text/Sublime\ Text/Packages/User/* $(HOME)/Library/Application\ Support/Sublime\ Text/Packages/User/; \
			sudo ln -sf $(CUR_DIR)/HOME/.config/sublime-text/Sublime\ Text/Packages/Dracula\ Color\ Scheme $(HOME)/Library/Application\ Support/Sublime\ Text/Packages; \
			sudo rm -f $(HOME)/Library/Application\ Support/Sublime\ Text/Packages/User/Preferences.sublime-settings; \
			sudo cp -f $(CUR_DIR)/HOME/.config/sublime-text/Sublime\ Text/Packages/User/Preferences.sublime-settings $(HOME)/Library/Application\ Support/Sublime\ Text/Packages/User/; \
	fi

.PHONY: os
os:
	@read -p "Choose an option (work/private): " OPTION; \
	DEVICE=$$OPTION; \
	export DEVICE; \
	if [ "$(OS)" = "osx" ]; then \
		echo "$(OS) detected"; \
		echo "run .macos"; \
		sudo -v; \
		while true; do sudo -n true; sleep 60; kill -0 $$ || exit; done 2>/dev/null & \
		bash -c "source $(CUR_DIR)/OS/osx/.macos"; \
		echo "install Brewfile"; \
		brew bundle --file=$(CUR_DIR)/OS/osx/Brewfile_$${DEVICE}; \
		echo "source duti-file"; \
		bash -c "source $(CUR_DIR)/OS/osx/duti.sh"; \
		mkdir -p $(HOME)/.qutebrowser; \
		ln -sf $(HOME)/.dotfiles/HOME/.config/qutebrowser/* $(HOME)/.qutebrowser/; \
	elif [ "$(OS)" = "linux" ]; then \
		echo "$(OS) detected"; \
	elif [ "$(OS)" = "wsl" ]; then \
		echo "$(OS) detected"; \
		echo "install packages"; \
		sudo apt install -y zsh procps curl file git tmux ranger; \
		echo "install linuxbrew"; \
		/bin/bash -c "$(curl --no-keepalive -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"; \
	fi
	@if [ -z "`${SHELL} -c 'echo ${ZSH_VERSION}'`" ]; then \
	  sudo sh -c "echo $(which zsh) >> /etc/shells" \
	  chsh -s "$(which zsh)"; \
	fi

.PHONY: rust
rust:
	@echo "rust-up"; \
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

.PHONY: asdf
asdf:
	git clone https://github.com/asdf-vm/asdf.git $(HOME)/.asdf --branch v0.14.0;

.PHONY: repos
repos:
	git clone https://github.com/alexchaichan/data-science.git $(HOME)/data-science; \
	git clone https://github.com/alexchaichan/cheatsheets.git $(HOME)/cheatsheets; \
	git clone https://github.com/alexchaichan/Templates.git $(HOME)/Templates; \
	git clone https://github.com/pandoc/lua-filters.git $(HOME)/.local/share/pandoc/filters;

.PHONY: passwords
passwords:
	echo | pass spotify/spotify-tui  > $(HOME)/.config/spotify-tui/client.yml; \
	echo | pass spotify/spotifyd  > $(HOME)/.cache/spotifyd/credentials.json;

