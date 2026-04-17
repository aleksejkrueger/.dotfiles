#!/bin/zsh

set -eu

helper_root="${HOME}/notes/vimwiki"
helper_script="${HOME}/.dotfiles/extensions/brave-notes-tags-extension/helper/note_server.py"
helper_host="127.0.0.1"
helper_port="8765"
log_file="${TMPDIR:-/tmp}/brave-notes-tags-helper.log"

if [[ ! -d "${helper_root}" ]]; then
  exit 0
fi

if [[ ! -f "${helper_script}" ]]; then
  exit 0
fi

if lsof -nP -iTCP:"${helper_port}" -sTCP:LISTEN 2>/dev/null | grep -Fq "${helper_host}:${helper_port}"; then
  exit 0
fi

(
  unset TMUX
  nohup python3 "${helper_script}" --root "${helper_root}" --host "${helper_host}" --port "${helper_port}" >>"${log_file}" 2>&1 &
) >/dev/null 2>&1
