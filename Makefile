.PHONY: help
help:
	@echo "Available targets:"
	@echo "  help         - Display this help message."
	@echo "  test         - Display detected OS, current directory, and username."
	@echo "  setup        - Run the setup process which includes test, scripts, symlinks, alacritty, and os."
	@echo "  os           - Perform OS-specific setup tasks (macOS, Linux, or WSL)."
	@echo "  scripts      - Make all scripts in the 'scripts' directory executable and symlink them to '/usr/local/bin/'."
	@echo "  stow     	  - Create necessary symlinks by using stow"
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
setup: test scripts stow os
	@echo "fnished"

.PHONY: scripts
scripts:
	chmod +x $(CUR_DIR)/src/*; \
	sudo ln -sf $(CUR_DIR)/src/* /usr/local/bin/;

.PHONY: stow
stow:
	cd $(CURDIR)/HOME && stow --ignore='\.DS_Store' -t $(HOME) ./

.PHONY: rust
rust:
	@echo "rust-up"; \
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

.PHONY: asdf
asdf:
	git clone https://github.com/asdf-vm/asdf.git $(HOME)/.asdf --branch v0.14.0;

.PHONY: repos
repos:
	echo ""


