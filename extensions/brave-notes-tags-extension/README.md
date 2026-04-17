# Local Notes Tag Finder

Chromium extension for Brave/Chrome backed by a local read-only helper.

The extension:

- fetches markdown notes from `http://127.0.0.1:8765`
- reads Obsidian-style YAML frontmatter
- filters notes by tags plus created/modified dates
- shows previews
- opens the selected note in an in-browser viewer
- can open a selected note in a new tmux window running `nvim`

The helper:

- reads files only from your local notes folder
- rescans the folder whenever the extension refreshes
- reads file metadata such as created and modified times
- auto-selects a default tmux session and creates a tmux window there to open a note in `nvim`
- does not upload anything anywhere

## Start the local helper

Run this in Terminal:

```bash
python3 /Users/aleksej.chaichan/brave-notes-tags-extension/helper/note_server.py \
  --root /Users/aleksej.chaichan/notes/vimwiki \
  --tmux-session main
```

Leave that process running.

## Load the extension in Brave

1. Open `brave://extensions`.
2. Enable `Developer mode`.
3. Click `Load unpacked`.
4. Select:

```text
/Users/aleksej.chaichan/brave-notes-tags-extension
```

5. In the extension details, enable `Allow access to file URLs`.
6. Reload the extension after any local code change.

## Use it

1. Start the helper.
2. Open the extension popup.
3. Click `Refresh Notes`.
4. Enter one or more tags and, if needed, narrow by created/modified date.
5. Click `Open File` to view the note in Brave, or `Open In Tmux` to open it in `nvim`.

## Behavior

- The popup reloads automatically when you reopen it.
- Cached notes remain visible if the helper is temporarily offline.
- New files appear after the popup refreshes or when you click `Refresh Notes`.
- Changed files are picked up after the popup refreshes or when you click `Refresh Notes`.
- Tag matching is case-insensitive.
- If you enter multiple tags, any matching tag is enough.
- Created and modified filters use filesystem timestamps from the helper host.
- If you do not pass `--tmux-session`, the helper auto-picks a session. It prefers the helper's current tmux session, then an attached or most recently attached session.
- The helper binds to `127.0.0.1` by default and is read-only.
