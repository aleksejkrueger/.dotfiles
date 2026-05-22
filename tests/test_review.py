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


class ReviewRangeTest(unittest.TestCase):
    """Tests for review range selection and command construction."""

    def test_diff_ref_uses_three_dot_for_branch_review(self) -> None:
        """Use merge-base comparison for the normal base branch flow."""
        review = load_review()
        ref_range = review["review_range"]("main")

        self.assertEqual(review["diff_ref"](ref_range), "main...HEAD")

    def test_diff_ref_uses_two_dot_for_explicit_refs(self) -> None:
        """Use exact two-ref comparison for --from/--to."""
        review = load_review()
        ref_range = review["review_range"]("abc123", "def456", explicit=True)

        self.assertEqual(review["diff_ref"](ref_range), "abc123..def456")

    def test_state_key_keeps_branch_name_for_base_review(self) -> None:
        """Keep existing state directories for base-vs-current-branch reviews."""
        review = load_review()

        def fake_branch_name() -> str:
            """Return a stable branch name for state-key assertions."""
            return "feature/demo"

        review["state_key"].__globals__["branch_name"] = fake_branch_name

        self.assertEqual(review["state_key"](review["review_range"]("main")), "main...feature-demo")

    def test_normalize_args_moves_explicit_range_before_subcommand(self) -> None:
        """Allow --from and --to after a subcommand."""
        review = load_review()

        normalized = review["normalize_args"](["status", "--from", "abc123", "--to=def456"])

        self.assertEqual(normalized, ["--from", "abc123", "--to=def456", "status"])

    def test_normalize_args_moves_ignore_before_subcommand(self) -> None:
        """Allow --ignore after a subcommand."""
        review = load_review()

        normalized = review["normalize_args"](["status", "--ignore", "tests/*", "--ignore=*.md"])

        self.assertEqual(normalized, ["--ignore", "tests/*", "--ignore=*.md", "status"])

    def test_review_range_from_args_builds_explicit_range(self) -> None:
        """Build a ReviewRange from explicit refs."""
        review = load_review()
        parser = review["parser"]()
        args = parser.parse_args(review["normalize_args"](["status", "--from", "abc123", "--to", "def456"]))

        ref_range = review["review_range_from_args"](args)

        self.assertEqual(ref_range.base, "abc123")
        self.assertEqual(ref_range.target, "def456")
        self.assertTrue(ref_range.explicit)

    def test_diff_command_uses_explicit_range_and_labels(self) -> None:
        """Build git diff with two-dot refs for explicit comparisons."""
        review = load_review()
        ref_range = review["review_range"]("abc123", "def456", explicit=True)

        command = review["diff_command"](ref_range, "src/app.py", "feature/demo")

        self.assertIn("abc123..def456", command)
        self.assertIn("--src-prefix=abc123/", command)
        self.assertIn("--dst-prefix=def456/", command)

    def test_rendered_new_line_matches_right_side_line_number(self) -> None:
        """Match the new-side diff line number, not the old side or code text."""
        review = load_review()

        self.assertFalse(review["rendered_new_line_matches"]("│ 99 │ old code │ 98 │ value = 99", 99))
        self.assertTrue(review["rendered_new_line_matches"]("│ 98 │ old code │ 99 │ selected", 99))

    def test_open_review_request_skips_empty_review_range(self) -> None:
        """Do not delegate to provider CLIs when there are no changed files."""
        review = load_review()
        app = review["ReviewApp"].__new__(review["ReviewApp"])
        app.files = []
        app.ref_range = review["review_range"]("main")
        called = False

        def fake_detect_provider() -> str:
            """Fail if provider detection is reached."""
            nonlocal called
            called = True
            return "gitlab"

        review["ReviewApp"].open_review_request.__globals__["detect_provider"] = fake_detect_provider

        app.open_review_request()

        self.assertFalse(called)
        self.assertEqual(app.message, "Open cancelled: no changed files in main...HEAD.")

    def test_jump_diff_to_line_scrolls_to_exact_rendered_line(self) -> None:
        """Put the requested rendered diff line at the top of the diff pane."""
        review = load_review()

        class FakeScreen:
            """Minimal screen object for jump tests."""

            def getmaxyx(self) -> tuple[int, int]:
                """Return a stable terminal size."""
                return 40, 120

        app = review["ReviewApp"].__new__(review["ReviewApp"])
        app.screen = FakeScreen()
        app.ref_range = review["review_range"]("main")
        app.branch = "feature/demo"
        app.diff_scroll = 0
        app.diff_cache = {
            ("src/app.py", 120): [
                "│ 97 │ old │ 97 │ previous",
                "│ 99 │ old │ 98 │ context 99",
                "│ 98 │ old │ 99 │ selected",
                "│ 100 │ old │ 100 │ next",
            ]
        }

        found = app.jump_diff_to_line("src/app.py", 99)

        self.assertTrue(found)
        self.assertEqual(app.diff_scroll, 2)

    def test_checked_files_returns_reviewed_changed_files(self) -> None:
        """List only changed files marked reviewed in state."""
        review = load_review()
        ref_range = review["review_range"]("main")

        def fake_changed_files(range_arg: object, ignore_patterns: object = ()) -> list[object]:
            """Return a stable changed file list."""
            self.assertEqual(range_arg, ref_range)
            self.assertEqual(ignore_patterns, ("docs/*",))
            return [
                review["ChangedFile"](1, "src/one.py"),
                review["ChangedFile"](2, "src/two.py"),
                review["ChangedFile"](3, "src/three.py"),
            ]

        def fake_load_state(range_arg: object) -> dict[str, object]:
            """Return reviewed state with one stale path."""
            self.assertEqual(range_arg, ref_range)
            return {"reviewed": ["src/two.py", "stale.py"]}

        checked_files = review["checked_files"]
        checked_files.__globals__["changed_files"] = fake_changed_files
        checked_files.__globals__["load_state"] = fake_load_state

        files = checked_files(ref_range, ("docs/*",))

        self.assertEqual([changed_file.path for changed_file in files], ["src/two.py"])

    def test_reviewable_files_skip_ignored_files_and_renumber(self) -> None:
        """Return only non-ignored changed files with stable display indexes."""
        review = load_review()
        ref_range = review["review_range"]("main")

        def fake_changed_files(range_arg: object, ignore_patterns: object = ()) -> list[object]:
            """Return a stable changed file list."""
            self.assertEqual(range_arg, ref_range)
            self.assertEqual(ignore_patterns, ("*.lock",))
            return [
                review["ChangedFile"](1, "src/one.py"),
                review["ChangedFile"](2, "src/two.py"),
                review["ChangedFile"](3, "src/three.py"),
            ]

        def fake_load_state(range_arg: object) -> dict[str, object]:
            """Return ignored state."""
            self.assertEqual(range_arg, ref_range)
            return {"ignored": ["src/two.py"]}

        reviewable_files = review["reviewable_files"]
        reviewable_files.__globals__["changed_files"] = fake_changed_files
        reviewable_files.__globals__["load_state"] = fake_load_state

        files = reviewable_files(ref_range, ("*.lock",))

        self.assertEqual(
            [(changed_file.index, changed_file.path) for changed_file in files],
            [(1, "src/one.py"), (2, "src/three.py")],
        )

    def test_toggle_ignored_persists_ignored_paths(self) -> None:
        """Toggle ignored file paths in review state."""
        review = load_review()
        state: dict[str, object] = {"ignored": ["src/old.py"], "reviewed": ["src/app.py"]}
        saved_states: list[dict[str, object]] = []

        def fake_load_state(scope: object) -> dict[str, object]:
            """Return the current in-memory state."""
            return state

        def fake_save_state(scope: object, updated_state: dict[str, object]) -> None:
            """Record saved state."""
            snapshot = updated_state.copy()
            saved_states.append(snapshot)
            state.clear()
            state.update(snapshot)

        toggle_ignored = review["toggle_ignored"]
        toggle_ignored.__globals__["load_state"] = fake_load_state
        toggle_ignored.__globals__["save_state"] = fake_save_state

        self.assertTrue(toggle_ignored("main", "src/app.py"))
        self.assertFalse(toggle_ignored("main", "src/app.py"))

        self.assertEqual(saved_states[0]["ignored"], ["src/app.py", "src/old.py"])
        self.assertEqual(saved_states[1]["ignored"], ["src/old.py"])

    def test_visible_files_support_ignored_filter(self) -> None:
        """Keep ignored files visible only in all or ignored filters."""
        review = load_review()
        app = review["ReviewApp"].__new__(review["ReviewApp"])
        app.files = [
            review["ChangedFile"](1, "src/checked.py"),
            review["ChangedFile"](2, "src/ignored.py"),
            review["ChangedFile"](3, "src/open.py"),
        ]
        app.reviewed = {"src/checked.py"}
        app.ignored = {"src/ignored.py"}
        app.search_query = ""
        app.search_error = ""

        app.file_filter = "unchecked"
        self.assertEqual([changed_file.path for changed_file in app.visible_files()], ["src/open.py"])

        app.file_filter = "ignored"
        self.assertEqual([changed_file.path for changed_file in app.visible_files()], ["src/ignored.py"])

    def test_ignore_patterns_match_paths_directories_and_globs(self) -> None:
        """Match exact paths, directory prefixes, and glob patterns."""
        review = load_review()
        ignored_path = review["ignored_path"]

        self.assertTrue(ignored_path("src/app.py", ("src/app.py",)))
        self.assertTrue(ignored_path("src/package/app.py", ("src",)))
        self.assertTrue(ignored_path("docs/readme.md", ("*.md",)))
        self.assertFalse(ignored_path("src/app.py", ("tests/*",)))

    def test_changed_files_filters_ignored_paths_and_renumbers(self) -> None:
        """Hide ignored paths before assigning display indexes."""
        review = load_review()
        ref_range = review["review_range"]("main")

        def fake_check_output(command: list[str], stderr: object) -> bytes:
            """Return a nul-separated git diff path list."""
            self.assertEqual(command[:4], ["git", "diff", "--name-only", "-z"])
            return b"src/app.py\0tests/test_app.py\0README.md\0"

        with patch("subprocess.check_output", fake_check_output):
            files = review["changed_files"](ref_range, ("tests", "*.md"))

        self.assertEqual([(changed_file.index, changed_file.path) for changed_file in files], [(1, "src/app.py")])


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


class JiraIntegrationTest(unittest.TestCase):
    """Tests for Jira popup data helpers."""

    def test_jira_config_reads_work_config_and_jiratui_token(self) -> None:
        """Load Jira URL and user from work config without sourcing shell code."""
        review = load_review()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            work_config = root / "work.zsh"
            work_config.write_text(
                "\n".join(
                    (
                        "export JIRA_URL=https://jira.example.test",
                        "export JIRA_NAME=dev@example.test",
                        "export JIRA_TOKEN=$(pass jira/token)",
                    )
                ),
                encoding="utf-8",
            )
            jiratui_config = root / ".config" / "jiratui" / "config.yaml"
            jiratui_config.parent.mkdir(parents=True)
            jiratui_config.write_text("jira_api_token: yaml-token\n", encoding="utf-8")

            with patch.dict("os.environ", {"HOME": str(root), "WORK_CONFIG": str(work_config)}, clear=True):
                config = review["jira_config"]()

        self.assertEqual(config.base_url, "https://jira.example.test")
        self.assertEqual(config.user, "dev@example.test")
        self.assertEqual(config.token, "yaml-token")

    def test_jira_issue_key_from_branch(self) -> None:
        """Find a Jira issue key in a branch name."""
        review = load_review()

        self.assertEqual(review["jira_issue_key_from_text"]("feat/IPRO-123-something"), "IPRO-123")

    def test_jira_issue_from_json_maps_important_fields(self) -> None:
        """Parse important Jira issue fields and comments."""
        review = load_review()
        config = review["JiraConfig"]("https://jira.example.test", "dev@example.test", "token", "")
        raw_issue = {
            "key": "IPRO-123",
            "fields": {
                "summary": "Improve review tool",
                "status": {"name": "In Progress"},
                "issuetype": {"name": "Story"},
                "priority": {"name": "High"},
                "assignee": {"displayName": "Alice"},
                "reporter": {"displayName": "Bob"},
                "resolution": None,
                "labels": ["review"],
                "components": [{"name": "CLI"}],
                "fixVersions": [{"name": "1.2"}],
                "created": "2026-05-20T10:00:00.000+0000",
                "updated": "2026-05-21T11:00:00.000+0000",
                "description": "Ticket body",
            },
        }
        comment = review["JiraComment"]("Alice", "Looks good.", "2026-05-21T12:00:00.000+0000", "")

        issue = review["jira_issue_from_json"](config, raw_issue, [comment])

        self.assertEqual(issue.key, "IPRO-123")
        self.assertEqual(issue.url, "https://jira.example.test/browse/IPRO-123")
        self.assertEqual(issue.summary, "Improve review tool")
        self.assertEqual(issue.status, "In Progress")
        self.assertEqual(issue.assignee, "Alice")
        self.assertEqual(issue.components, ("CLI",))
        self.assertEqual(issue.comments, (comment,))

    def test_jira_comment_from_json_supports_document_body(self) -> None:
        """Convert Jira document-style comment bodies to readable text."""
        review = load_review()
        raw_comment = {
            "author": {"displayName": "Alice"},
            "body": {"content": [{"content": [{"text": "Hello"}]}, {"content": [{"text": "World"}]}]},
            "created": "2026-05-21T12:00:00.000+0000",
            "updated": "2026-05-21T12:01:00.000+0000",
        }

        comment = review["jira_comment_from_json"](raw_comment)

        self.assertEqual(comment.author, "Alice")
        self.assertEqual(comment.body, "Hello\nWorld")

    def test_jira_issue_popup_lines_include_comments(self) -> None:
        """Render Jira ticket details and comments for the popup."""
        review = load_review()

        def fake_color_pair(color: int, reverse: bool = False) -> int:
            """Avoid curses color initialization in tests."""
            return 0

        review["color_pair"] = fake_color_pair
        comment = review["JiraComment"]("Alice", "Please check this.", "2026-05-21T12:00:00.000+0000", "")
        issue = review["JiraIssue"](
            "IPRO-123",
            "https://jira.example.test/browse/IPRO-123",
            "Improve review tool",
            "In Progress",
            "Story",
            "High",
            "Alice",
            "Bob",
            "unresolved",
            ("review",),
            ("CLI",),
            ("1.2",),
            "2026-05-20T10:00:00.000+0000",
            "2026-05-21T11:00:00.000+0000",
            "Ticket body",
            (comment,),
        )

        lines = review["jira_issue_popup_lines"](issue, 80)
        text = "\n".join(line for line, _mode in lines)

        self.assertIn("IPRO-123", text)
        self.assertIn("Status: In Progress", text)
        self.assertIn("Comments (1)", text)
        self.assertIn("Please check this.", text)


class HelpPopupTest(unittest.TestCase):
    """Tests for in-app help rendering."""

    def test_help_popup_lines_include_main_comment_and_jira_keys(self) -> None:
        """Render useful help for the main TUI and popups."""
        review = load_review()

        def fake_color_pair(color: int, reverse: bool = False) -> int:
            """Avoid curses color initialization in tests."""
            return 0

        review["color_pair"] = fake_color_pair

        lines = review["help_popup_lines"](100)
        text = "\n".join(line for line, _mode in lines)

        self.assertIn("Main", text)
        self.assertIn("?            show this help", text)
        self.assertIn("m            open comments popup", text)
        self.assertIn("t            open Jira ticket popup", text)
        self.assertIn("Comments Popup", text)
        self.assertIn("A            apply selected suggestion", text)
        self.assertIn("Jira Popup", text)
        self.assertIn("a            add a Jira comment", text)


if __name__ == "__main__":
    unittest.main()
