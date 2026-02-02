# Copilot Instructions for .dotfiles

## Build, Test, and Lint Commands

- **Setup:**
  - `make setup` — Runs the full setup process (test, scripts, symlinks, alacritty, OS-specific setup)
  - `make os` — Runs OS-specific setup (macOS, Linux, or WSL)
  - `make scripts` — Makes all scripts in `src/` executable and symlinks them to `/usr/local/bin/`
  - `make stow` — Creates symlinks for dotfiles in `HOME/` to the user's home directory
  - `make test` — Prints detected OS, current directory, and username
  - **Single step:** You can run any individual Makefile target as needed (e.g., `make scripts`)

- **Python requirements:**
  - Install with `pip install -r requirements.txt`

## High-Level Architecture

- **Dotfiles Structure:**
  - `HOME/` contains user configuration files and directories to be symlinked into `$HOME`
  - `OS/` contains OS-specific setup scripts and Brewfiles
  - `src/` contains utility scripts (wrappers, helpers, automation for tools like pass, pinentry, spotifyd, spt, w3m, tmux, etc.)
  - `fonts/` contains custom fonts
  - `requirements.txt` lists Python dependencies for development tools

- **Symlinking:**
  - The `stow` Makefile target and `src/symlinks` script automate symlinking files from `HOME/` to the user's home directory

- **OS Detection:**
  - `src/detect_os` script determines the current OS (osx, linux, wsl) and is used by the Makefile for conditional logic

- **Setup Flow:**
  1. Clone the repo and submodules
  2. Restore `.password-store`, `.gnupg`, and `.ssh` to `$HOME` as needed
  3. Run `make setup` to initialize everything

## Key Conventions

- **Script Wrappers:**
  - Scripts in `src/` wrap system binaries, preferring `/usr/local/bin`, `/usr/bin`, or Homebrew paths, and fallback with error if not found
  - Some scripts (e.g., `workup`, `tmux-cheatsheets`, `tmux-shells`) automate tmux sessions, note-taking, and shell selection

- **Device/Environment:**
  - The `make os` target prompts for device type (work/private) and uses the appropriate Brewfile for macOS

- **Password and Credentials:**
  - `make passwords` uses the `pass` utility to set up credentials for Spotify tools

- **Extensibility:**
  - To add new dotfiles, place them in `HOME/` and rerun `make stow` or the symlinks script

---

This file summarizes build/setup commands, architecture, and conventions for effective Copilot use in this repository. Would you like to adjust anything or add coverage for other areas (e.g., plugin management, onboarding, or advanced automation)?
