#!/usr/bin/env bash

set -euo pipefail

target_pane="${1:-}"
target_args=()
split_args=(-v -d -l 12)

if [[ -n "$target_pane" ]]; then
  target_args=(-t "$target_pane")
  split_args+=(-t "$target_pane")
fi

context_dir="$(tmux display-message -p "${target_args[@]}" '#{@nvim_context_dir}')"
context_command="$(tmux display-message -p "${target_args[@]}" '#{@nvim_context_command}')"
notebook_dir="$(tmux display-message -p "${target_args[@]}" '#{@nvim_ipynb_dir}')"
current_path="$(tmux display-message -p "${target_args[@]}" '#{pane_current_path}')"
start_path="$current_path"

if [[ -n "$context_dir" && -d "$context_dir" ]]; then
  start_path="$context_dir"
elif [[ -n "$notebook_dir" && -d "$notebook_dir" ]]; then
  start_path="$notebook_dir"
fi

shell_quote() {
  printf '%q' "$1"
}

find_venv() {
  local directory="$1"

  while [[ -n "$directory" && "$directory" != "/" ]]; do
    if [[ -d "$directory/.venv" ]]; then
      printf '%s\n' "$directory/.venv"
      return 0
    fi

    directory="$(dirname "$directory")"
  done

  return 1
}

venv_python_command() {
  local venv_path
  local python_path

  venv_path="$(find_venv "$start_path")" || return 1

  if [[ -x "$venv_path/bin/ipython" ]]; then
    shell_quote "$venv_path/bin/ipython"
    return 0
  fi

  python_path="$venv_path/bin/python"

  if [[ ! -x "$python_path" ]]; then
    return 1
  fi

  if "$python_path" -c 'import IPython' >/dev/null 2>&1; then
    printf '%s -m IPython' "$(shell_quote "$python_path")"
  else
    tmux display-message "IPython not installed in .venv; opened venv python"
    shell_quote "$python_path"
  fi
}

resolve_context_command() {
  if [[ "$context_command" == "ipython" ]]; then
    venv_python_command && return 0
  fi

  if command -v "$context_command" >/dev/null 2>&1; then
    printf '%s\n' "$context_command"
    return 0
  fi

  return 1
}

if [[ -z "$context_command" ]]; then
  tmux split-window "${split_args[@]}" -c "$start_path"
elif command_to_run="$(resolve_context_command)"; then
  tmux split-window "${split_args[@]}" -c "$start_path" "$command_to_run"
else
  tmux display-message "Command not found: $context_command"
  tmux split-window "${split_args[@]}" -c "$start_path"
fi
