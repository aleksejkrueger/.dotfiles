#!/usr/bin/env bash

set -euo pipefail

target_pane="${1:-}"
target_args=()
split_args=(-v -d -l 12)
vars_width="${NVIM_VARS_WIDTH:-44}"
vars_hook_version=10
vars_ui_version=10

if [[ -z "$target_pane" ]]; then
  target_pane="$(tmux display-message -p '#{pane_id}')"
fi

target_args=(-t "$target_pane")
split_args+=(-t "$target_pane")

context_dir="$(tmux display-message -p "${target_args[@]}" '#{@nvim_context_dir}')"
context_command="$(tmux display-message -p "${target_args[@]}" '#{@nvim_context_command}')"
notebook_dir="$(tmux display-message -p "${target_args[@]}" '#{@nvim_ipynb_dir}')"
current_path="$(tmux display-message -p "${target_args[@]}" '#{pane_current_path}')"
start_path="$current_path"
vars_script="${HOME}/.dotfiles/src/repl-vars"
vars_hook_script="${HOME}/.dotfiles/src/repl-vars-hook.py"
r_vars_hook_script="${HOME}/.dotfiles/src/repl-vars-hook.R"

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
    ipython_command "$venv_path/bin/ipython"
    return 0
  fi

  python_path="$venv_path/bin/python"

  if [[ ! -x "$python_path" ]]; then
    return 1
  fi

  if "$python_path" -c 'import IPython' >/dev/null 2>&1; then
    ipython_module_command "$python_path"
  else
    tmux display-message "IPython not installed in .venv; opened venv python"
    shell_quote "$python_path"
  fi
}

ipython_command() {
  local executable="$1"

  if [[ -f "$vars_hook_script" && -n "${vars_file:-}" ]]; then
    printf 'NVIM_TMUX_VARS_FILE=%s %s -i %s\n' \
      "$(shell_quote "$vars_file")" \
      "$(shell_quote "$executable")" \
      "$(shell_quote "$vars_hook_script")"
  else
    shell_quote "$executable"
  fi
}

ipython_module_command() {
  local python_path="$1"

  if [[ -f "$vars_hook_script" && -n "${vars_file:-}" ]]; then
    printf 'NVIM_TMUX_VARS_FILE=%s %s -m IPython -i %s\n' \
      "$(shell_quote "$vars_file")" \
      "$(shell_quote "$python_path")" \
      "$(shell_quote "$vars_hook_script")"
  else
    printf '%s -m IPython\n' "$(shell_quote "$python_path")"
  fi
}

r_executable() {
  if command -v R >/dev/null 2>&1; then
    command -v R
    return 0
  fi

  for candidate in /opt/homebrew/bin/R /usr/local/bin/R /usr/bin/R; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

r_command() {
  local executable="$1"

  if [[ -f "$r_vars_hook_script" && -n "${vars_file:-}" ]]; then
    printf 'NVIM_TMUX_VARS_FILE=%s NVIM_TMUX_R_PROFILE_USER=%s NVIM_TMUX_R_HOOK_FILE=%s R_PROFILE_USER=%s %s --quiet --no-save --no-restore\n' \
      "$(shell_quote "$vars_file")" \
      "$(shell_quote "${R_PROFILE_USER:-}")" \
      "$(shell_quote "$r_vars_hook_script")" \
      "$(shell_quote "$r_vars_hook_script")" \
      "$(shell_quote "$executable")"
  else
    shell_quote "$executable"
  fi
}

hooked_context_command() {
  [[ "$1" == "ipython" || "$1" == "R" ]]
}

vars_language_for_context() {
  if [[ "$context_command" == "R" ]]; then
    printf 'r\n'
  else
    printf 'python\n'
  fi
}

resolve_context_command() {
  local r_path

  if [[ "$context_command" == "ipython" ]]; then
    venv_python_command && return 0
  fi

  if [[ "$context_command" == "R" ]]; then
    r_path="$(r_executable)" || return 1
    r_command "$r_path"
    return 0
  fi

  if command -v "$context_command" >/dev/null 2>&1; then
    if [[ "$context_command" == "ipython" ]]; then
      ipython_command "$context_command"
    else
      printf '%s\n' "$context_command"
    fi
    return 0
  fi

  return 1
}

pane_exists() {
  local pane="$1"
  local resolved_pane

  if [[ -z "$pane" ]]; then
    return 1
  fi

  resolved_pane="$(tmux display-message -p -t "$pane" '#{pane_id}' 2>/dev/null || true)"
  [[ "$resolved_pane" == "$pane" ]]
}

safe_target_name() {
  local raw_name

  raw_name="$(tmux display-message -p "${target_args[@]}" '#{session_id}-#{window_id}-#{pane_id}')"
  printf '%s\n' "${raw_name//[^[:alnum:]_.-]/_}"
}

vars_file_for_target() {
  local safe_name

  safe_name="$(safe_target_name)"
  printf '%s/nvim-vars-%s.json\n' "${TMPDIR:-/tmp}" "$safe_name"
}

write_initial_vars_file() {
  local vars_file="$1"

  if [[ -f "$vars_file" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$vars_file")"
  printf '{"updated_at":"","message":"Waiting for REPL variables.","vars":[]}\n' >"$vars_file"
}

create_repl_pane() {
  local pane_id

  if [[ -z "$context_command" ]]; then
    pane_id="$(tmux split-window "${split_args[@]}" -P -F '#{pane_id}' -c "$start_path")"
  elif command_to_run="$(resolve_context_command)"; then
    pane_id="$(tmux split-window "${split_args[@]}" -P -F '#{pane_id}' -c "$start_path" "$command_to_run")"
  else
    tmux display-message "Command not found: $context_command"
    pane_id="$(tmux split-window "${split_args[@]}" -P -F '#{pane_id}' -c "$start_path")"
  fi

  printf '%s\n' "$pane_id"
}

respawn_repl_pane() {
  local repl_pane="$1"

  if [[ -z "$context_command" ]]; then
    tmux respawn-pane -k -t "$repl_pane" -c "$start_path"
  elif command_to_run="$(resolve_context_command)"; then
    tmux respawn-pane -k -t "$repl_pane" -c "$start_path" "$command_to_run"
  else
    tmux display-message "Command not found: $context_command"
    tmux respawn-pane -k -t "$repl_pane" -c "$start_path"
  fi

  printf '%s\n' "$repl_pane"
}

vars_command_for() {
  local repl_pane="$1"
  local vars_file="$2"
  local vars_language="$3"

  if [[ ! -x "$vars_script" ]]; then
    tmux display-message "Vars browser missing or not executable: $vars_script"
    return 1
  fi

  printf '%s --vars-file %s --target-pane %s --language %s\n' \
    "$(shell_quote "$vars_script")" \
    "$(shell_quote "$vars_file")" \
    "$(shell_quote "$repl_pane")" \
    "$(shell_quote "$vars_language")"
}

create_vars_pane() {
  local repl_pane="$1"
  local vars_file="$2"
  local vars_language="$3"
  local vars_command

  vars_command="$(vars_command_for "$repl_pane" "$vars_file" "$vars_language")"
  tmux split-window -h -d -l "$vars_width" -P -F '#{pane_id}' -t "$target_pane" -c "$start_path" "$vars_command"
}

respawn_vars_pane() {
  local vars_pane="$1"
  local repl_pane="$2"
  local vars_file="$3"
  local vars_language="$4"
  local vars_command

  vars_command="$(vars_command_for "$repl_pane" "$vars_file" "$vars_language")"
  tmux respawn-pane -k -t "$vars_pane" -c "$start_path" "$vars_command"
  printf '%s\n' "$vars_pane"
}

existing_repl_pane="$(tmux display-message -p "${target_args[@]}" '#{@nvim_repl_pane}')"
existing_repl_context_command="$(tmux display-message -p "${target_args[@]}" '#{@nvim_repl_context_command}')"
existing_repl_vars_file="$(tmux display-message -p "${target_args[@]}" '#{@nvim_repl_vars_file}')"
existing_repl_hook_version="$(tmux display-message -p "${target_args[@]}" '#{@nvim_repl_hook_version}')"
existing_vars_pane="$(tmux display-message -p "${target_args[@]}" '#{@nvim_vars_pane}')"
existing_vars_target_pane="$(tmux display-message -p "${target_args[@]}" '#{@nvim_vars_target_pane}')"
existing_vars_ui_version="$(tmux display-message -p "${target_args[@]}" '#{@nvim_vars_ui_version}')"
existing_vars_file="$(tmux display-message -p "${target_args[@]}" '#{@nvim_vars_file}')"
existing_vars_language="$(tmux display-message -p "${target_args[@]}" '#{@nvim_vars_language}')"

if [[ -n "$existing_vars_file" ]]; then
  vars_file="$existing_vars_file"
else
  vars_file="$(vars_file_for_target)"
fi

vars_language="$(vars_language_for_context)"
write_initial_vars_file "$vars_file"

if pane_exists "$existing_repl_pane"; then
  if [[ "$existing_repl_context_command" == "$context_command" ]] && { ! hooked_context_command "$context_command" || [[ "$existing_repl_vars_file" == "$vars_file" && "$existing_repl_hook_version" == "$vars_hook_version" ]]; }; then
    repl_pane="$existing_repl_pane"
  else
    repl_pane="$(respawn_repl_pane "$existing_repl_pane")"
  fi
else
  repl_pane="$(create_repl_pane)"
fi

if pane_exists "$existing_vars_pane"; then
  if [[ "$existing_vars_target_pane" == "$repl_pane" && "$existing_vars_ui_version" == "$vars_ui_version" && "$existing_vars_language" == "$vars_language" ]]; then
    vars_pane="$existing_vars_pane"
  else
    vars_pane="$(respawn_vars_pane "$existing_vars_pane" "$repl_pane" "$vars_file" "$vars_language" || true)"
  fi
else
  vars_pane="$(create_vars_pane "$repl_pane" "$vars_file" "$vars_language" || true)"
fi

tmux set-option -p "${target_args[@]}" @nvim_repl_pane "$repl_pane"
tmux set-option -p "${target_args[@]}" @nvim_repl_context_command "$context_command"
tmux set-option -p "${target_args[@]}" @nvim_repl_vars_file "$vars_file"
tmux set-option -p "${target_args[@]}" @nvim_repl_hook_version "$vars_hook_version"
tmux set-option -p "${target_args[@]}" @nvim_vars_file "$vars_file"

if [[ -n "$vars_pane" ]]; then
  tmux set-option -p "${target_args[@]}" @nvim_vars_pane "$vars_pane"
  tmux set-option -p "${target_args[@]}" @nvim_vars_target_pane "$repl_pane"
  tmux set-option -p "${target_args[@]}" @nvim_vars_ui_version "$vars_ui_version"
  tmux set-option -p "${target_args[@]}" @nvim_vars_language "$vars_language"
  tmux display-message "REPL pane ${repl_pane#%}, vars pane ${vars_pane#%}"
else
  tmux display-message "REPL pane ${repl_pane#%}"
fi
