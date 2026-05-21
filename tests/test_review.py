"""Tests for the review CLI helper."""

from __future__ import annotations

import json
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REVIEW_SCRIPT = Path(__file__).resolve().parents[1] / "src" / "review"


def load_review() -> dict[str, object]:
    """Load the review script without running the CLI entrypoint."""
    return runpy.run_path(str(REVIEW_SCRIPT), run_name="review_test")


class EditorCommandTest(unittest.TestCase):
    """Tests for editor command selection."""

    def test_open_file_uses_visual_editor(self) -> None:
        """Use VISUAL as the default editor when opening a file."""
        review = load_review()
        calls: list[list[str]] = []

        def fake_call(command: list[str]) -> int:
            """Record the command instead of executing it."""
            calls.append(command)
            return 0

        open_file = review["open_file"]
        open_file.__globals__["call"] = fake_call
        with patch.dict("os.environ", {"VISUAL": "zed", "EDITOR": "nvim"}, clear=False):
            open_file("src/review")

        self.assertEqual(calls, [["zed", "src/review"]])

    def test_editor_command_supports_arguments(self) -> None:
        """Preserve editor arguments before appending the file path."""
        review = load_review()
        with patch.dict("os.environ", {"VISUAL": "zed --wait", "EDITOR": "nvim"}, clear=False):
            command = review["editor_command"]("src/review")

        self.assertEqual(command, ["zed", "--wait", "src/review"])

    def test_editor_command_uses_editor_when_visual_is_missing(self) -> None:
        """Use EDITOR when VISUAL is not configured."""
        review = load_review()
        with patch.dict("os.environ", {"EDITOR": "zed"}, clear=True):
            command = review["editor_command"]("src/review")

        self.assertEqual(command, ["zed", "src/review"])


class ReplyDraftTest(unittest.TestCase):
    """Tests for reply draft state helpers."""

    def test_reply_draft_state_roundtrip(self) -> None:
        """Serialize and parse reply drafts without provider calls."""
        review = load_review()
        draft = review["ReplyDraft"]("", "thread-1", "note-1", "src/app.py", 12, "Looks good now.")
        state = review["reply_draft_state"](draft)
        drafts = review["reply_drafts"]({"reply_drafts": [state, {"body": ""}, "bad"]})

        self.assertEqual(len(drafts), 1)
        self.assertEqual(drafts[0].thread_id, "thread-1")
        self.assertEqual(drafts[0].note_id, "note-1")
        self.assertEqual(drafts[0].body, "Looks good now.")
        self.assertTrue(drafts[0].draft_id)

    def test_update_reply_draft_body_keeps_existing_draft(self) -> None:
        """Edit an existing draft without creating another draft."""
        review = load_review()
        draft = review["ReplyDraft"]("draft-1", "thread-1", "note-1", "src/app.py", 12, "First line.")
        state = {"reply_drafts": [review["reply_draft_state"](draft)]}
        saved_states: list[dict[str, object]] = []

        def fake_load_state(base: str) -> dict[str, object]:
            """Return the current in-memory state."""
            return state

        def fake_save_state(base: str, saved_state: dict[str, object]) -> None:
            """Record the saved state."""
            saved_states.append(saved_state)

        update_reply_draft_body = review["update_reply_draft_body"]
        update_reply_draft_body.__globals__["load_state"] = fake_load_state
        update_reply_draft_body.__globals__["save_state"] = fake_save_state

        updated = update_reply_draft_body("main", draft, "Changed text.")
        saved_drafts = saved_states[0]["reply_drafts"]

        self.assertEqual(updated.body, "Changed text.")
        self.assertEqual(len(saved_drafts), 1)
        self.assertEqual(saved_drafts[0]["draft_id"], "draft-1")
        self.assertEqual(saved_drafts[0]["body"], "Changed text.")

    def test_reply_draft_matches_target(self) -> None:
        """Match drafts to the selected remote note."""
        review = load_review()
        note = review["RemoteNote"]("src/app.py", 12, "alice", "Please adjust.", "note-1")
        thread = review["RemoteThread"]("thread-1", "src/app.py", 12, (note,))
        target = review["ReplyTarget"](thread, note)
        draft = review["ReplyDraft"]("draft-1", "thread-1", "note-1", "src/app.py", 12, "Done.")

        self.assertTrue(review["reply_draft_matches_target"](draft, target))

    def test_comment_popup_allows_selecting_reply_drafts(self) -> None:
        """Include saved reply drafts in the popup selection list."""
        review = load_review()

        def fake_color_pair(color: int, reverse: bool = False) -> int:
            """Avoid curses color initialization in tests."""
            return 0

        review["color_pair"] = fake_color_pair
        note = review["RemoteNote"]("src/app.py", 12, "alice", "Please adjust.", "note-1")
        thread = review["RemoteThread"]("thread-1", "src/app.py", 12, (note,))
        target = review["ReplyTarget"](thread, note)
        draft = review["ReplyDraft"]("draft-1", "thread-1", "note-1", "src/app.py", 12, "Done.")
        app = review["ReviewApp"].__new__(review["ReviewApp"])
        app.files = [review["ChangedFile"](0, "src/app.py")]
        app.selected = 0
        app.reviewed = set()
        app.search_query = ""
        app.search_error = ""
        app.file_filter = "all"
        app.comments_by_path = {}
        app.remote_threads_by_path = {"src/app.py": [thread]}
        app.state = {"reply_drafts": [review["reply_draft_state"](draft)]}

        lines, target_ranges, targets = app.comment_popup_lines(80, 1)

        self.assertEqual(len(targets), 2)
        self.assertEqual(targets[0], review["CommentPopupSelection"](target))
        self.assertEqual(targets[1], review["CommentPopupSelection"](target, draft))
        self.assertTrue(lines[target_ranges[1][0]][0].startswith(">"))
        self.assertIn("draft 1", lines[target_ranges[1][0]][0])

    def test_comment_popup_scroll_shows_selected_block_body(self) -> None:
        """Scroll enough to show the selected comment body when it fits."""
        review = load_review()

        self.assertEqual(review["scroll_for_selected_block"](0, 5, 8, 11), 7)
        self.assertEqual(review["scroll_for_selected_block"](4, 5, 6, 8), 4)

    def test_note_suggestions_parse_gitlab_offsets(self) -> None:
        """Parse GitLab suggestion ranges relative to the commented line."""
        review = load_review()
        body = "Please use this:\n```suggestion:-1+2\nalpha\nbeta\n```"
        note = review["RemoteNote"]("src/app.py", 10, "alice", body, "note-1")

        suggestions = review["note_suggestions"](note)

        self.assertEqual(len(suggestions), 1)
        self.assertEqual(suggestions[0].start_line, 9)
        self.assertEqual(suggestions[0].end_line, 12)
        self.assertEqual(suggestions[0].body, "alpha\nbeta")

    def test_apply_suggestion_to_file_replaces_range(self) -> None:
        """Apply a selected suggestion to the working tree."""
        review = load_review()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.py"
            path.write_text("one\ntwo\nthree\n", encoding="utf-8")
            suggestion = review["ReviewSuggestion"]("suggestion-1", str(path), 2, 3, "zwei\ndrei")

            success, message = review["apply_suggestion_to_file"](suggestion)

            self.assertTrue(success)
            self.assertIn("Applied suggestion", message)
            self.assertEqual(path.read_text(encoding="utf-8"), "one\nzwei\ndrei\n")

    def test_restore_suggestion_undo_restores_original_file(self) -> None:
        """Restore the last saved suggestion snapshot."""
        review = load_review()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.py"
            path.write_text("changed\n", encoding="utf-8")
            undo = review["SuggestionUndo"](str(path), "original\n", "suggestion-1", 1, 1)
            state = {"suggestion_undo": review["suggestion_undo_state"](undo)}
            saved_states: list[dict[str, object]] = []

            def fake_load_state(base: str) -> dict[str, object]:
                """Return the in-memory undo state."""
                return state

            def fake_save_state(base: str, saved_state: dict[str, object]) -> None:
                """Record the updated state."""
                saved_states.append(saved_state)

            restore_undo = review["restore_suggestion_undo"]
            restore_undo.__globals__["load_state"] = fake_load_state
            restore_undo.__globals__["save_state"] = fake_save_state

            success, message = restore_undo("main")

            self.assertTrue(success)
            self.assertIn("Undid suggestion", message)
            self.assertEqual(path.read_text(encoding="utf-8"), "original\n")
            self.assertNotIn("suggestion_undo", saved_states[0])

    def test_build_suggestion_undo_stores_original_content(self) -> None:
        """Capture original file content before applying a suggestion."""
        review = load_review()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.py"
            path.write_text("one\n", encoding="utf-8")
            suggestion = review["ReviewSuggestion"]("suggestion-1", str(path), 1, 1, "two")

            undo, error = review["build_suggestion_undo"](suggestion)

            self.assertEqual(error, "")
            self.assertEqual(undo.path, str(path))
            self.assertEqual(undo.content, "one\n")
            self.assertEqual(undo.suggestion_id, "suggestion-1")

    def test_comment_popup_allows_selecting_suggestions(self) -> None:
        """Include parsed suggestions in the popup selection list."""
        review = load_review()

        def fake_color_pair(color: int, reverse: bool = False) -> int:
            """Avoid curses color initialization in tests."""
            return 0

        review["color_pair"] = fake_color_pair
        body = "Please use this:\n```suggestion\nupdated\n```"
        note = review["RemoteNote"]("src/app.py", 12, "alice", body, "note-1")
        thread = review["RemoteThread"]("thread-1", "src/app.py", 12, (note,))
        app = review["ReviewApp"].__new__(review["ReviewApp"])
        app.files = [review["ChangedFile"](0, "src/app.py")]
        app.selected = 0
        app.reviewed = set()
        app.search_query = ""
        app.search_error = ""
        app.file_filter = "all"
        app.comments_by_path = {}
        app.remote_threads_by_path = {"src/app.py": [thread]}
        app.state = {"reply_drafts": []}

        lines, target_ranges, targets = app.comment_popup_lines(80, 1)

        self.assertEqual(len(targets), 2)
        self.assertIsNotNone(targets[1].suggestion)
        self.assertTrue(lines[target_ranges[1][0]][0].startswith(">"))
        self.assertIn("suggestion 1", lines[target_ranges[1][0]][0])

    def test_comment_popup_hides_resolved_suggestions(self) -> None:
        """Do not present resolved suggestion blocks as actionable suggestions."""
        review = load_review()

        def fake_color_pair(color: int, reverse: bool = False) -> int:
            """Avoid curses color initialization in tests."""
            return 0

        review["color_pair"] = fake_color_pair
        body = "Already handled:\n```suggestion\nupdated\n```"
        note = review["RemoteNote"]("src/app.py", 12, "alice", body, "note-1")
        thread = review["RemoteThread"]("thread-1", "src/app.py", 12, (note,), resolved=True)
        app = review["ReviewApp"].__new__(review["ReviewApp"])
        app.files = [review["ChangedFile"](0, "src/app.py")]
        app.selected = 0
        app.reviewed = set()
        app.search_query = ""
        app.search_error = ""
        app.file_filter = "all"
        app.comments_by_path = {}
        app.remote_threads_by_path = {"src/app.py": [thread]}
        app.state = {"reply_drafts": []}

        _lines, _target_ranges, targets = app.comment_popup_lines(80, 0)

        self.assertEqual(len(targets), 1)
        self.assertIsNone(targets[0].suggestion)

    def test_gitlab_draft_note_thread_keeps_pending_suggestion(self) -> None:
        """Treat GitLab review drafts as pending selectable threads."""
        review = load_review()
        draft_note = {
            "id": 5,
            "note": "Please use this:\n```suggestion\nupdated\n```",
            "position": {"new_path": "src/app.py", "new_line": 12},
        }

        thread = review["gitlab_draft_note_thread"](draft_note, 1)

        self.assertIsNotNone(thread)
        self.assertTrue(thread.pending)
        self.assertFalse(thread.replyable)
        self.assertEqual(thread.path, "src/app.py")
        self.assertEqual(len(review["note_suggestions"](thread.notes[0])), 1)

    def test_github_pending_review_threads_are_loaded(self) -> None:
        """Fetch pending GitHub review comments from review-specific endpoints."""
        review = load_review()

        def fake_try_run(command: list[str], *, input_text: str | None = None) -> tuple[bool, str]:
            """Return pending review data for gh api calls."""
            endpoint = command[-1]
            if endpoint.endswith("/reviews"):
                return True, json.dumps([{"id": 42, "state": "PENDING"}])
            if endpoint.endswith("/reviews/42/comments"):
                return True, json.dumps(
                    [
                        {
                            "id": 99,
                            "path": "src/app.py",
                            "line": 12,
                            "start_line": 12,
                            "body": "Try this:\n```suggestion\nupdated\n```",
                            "user": {"login": "alice"},
                        }
                    ]
                )
            return False, "unexpected endpoint"

        fetch_pending = review["fetch_github_pending_review_threads"]
        fetch_pending.__globals__["try_run"] = fake_try_run

        threads = fetch_pending("owner/repo", "7")

        self.assertEqual(len(threads), 1)
        self.assertTrue(threads[0].pending)
        self.assertFalse(threads[0].replyable)
        self.assertEqual(threads[0].thread_id, "pending-review-42-99")
        self.assertEqual(len(review["note_suggestions"](threads[0].notes[0])), 1)

    def test_copy_popup_row_uses_selected_draft_body(self) -> None:
        """Copy the selected draft body instead of the parent note body."""
        review = load_review()
        copied: list[str] = []

        def fake_copy_to_clipboard(text: str) -> tuple[bool, str]:
            """Record copied text without touching the system clipboard."""
            copied.append(text)
            return True, "Copied selected comment."

        review["ReviewApp"].copy_selected_popup_row.__globals__["copy_to_clipboard"] = fake_copy_to_clipboard
        note = review["RemoteNote"]("src/app.py", 12, "alice", "Please adjust.", "note-1")
        thread = review["RemoteThread"]("thread-1", "src/app.py", 12, (note,))
        target = review["ReplyTarget"](thread, note)
        draft = review["ReplyDraft"]("draft-1", "thread-1", "note-1", "src/app.py", 12, "Done.")
        selection = review["CommentPopupSelection"](target, draft)
        app = review["ReviewApp"].__new__(review["ReviewApp"])

        message = app.copy_selected_popup_row(selection)

        self.assertEqual(message, "Copied selected comment.")
        self.assertEqual(copied, ["Done."])


class ThreadActionTest(unittest.TestCase):
    """Tests for comment thread actions."""

    def test_escape_key_cancels_prompt_modes(self) -> None:
        """Treat the Escape key as a prompt cancellation key."""
        review = load_review()

        self.assertTrue(review["is_escape_key"](27))

    def test_toggle_resolved_rejects_unsupported_provider(self) -> None:
        """Do not call provider APIs for unsupported resolve toggles."""
        review = load_review()
        note = review["RemoteNote"]("src/app.py", 12, "alice", "Please adjust.", "note-1")
        thread = review["RemoteThread"]("thread-1", "src/app.py", 12, (note,))

        message = review["toggle_remote_thread_resolved"]("github", thread)

        self.assertEqual(message, "Resolve toggle is only supported for GitLab threads.")

    def test_clipboard_commands_use_available_programs(self) -> None:
        """Return only clipboard commands that exist."""
        review = load_review()

        def fake_which(command: str) -> str | None:
            """Pretend only pbcopy is installed."""
            return "/usr/bin/pbcopy" if command == "pbcopy" else None

        with patch.object(review["shutil"], "which", fake_which):
            commands = review["clipboard_commands"]()

        self.assertEqual(commands, [["pbcopy"]])


if __name__ == "__main__":
    unittest.main()
