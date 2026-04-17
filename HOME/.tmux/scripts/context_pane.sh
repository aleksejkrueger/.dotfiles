#!/usr/bin/env bash

tmux split-window -v -l 12 -c "#{pane_current_path}"
