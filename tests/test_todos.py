"""Tests for the todos CLI helper."""

from __future__ import annotations

import os
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


TODOS_SCRIPT = Path(__file__).resolve().parents[1] / "src" / "todos"


def load_todos() -> dict[str, object]:
    """Load the todos script without running the CLI entrypoint."""
    return runpy.run_path(str(TODOS_SCRIPT), run_name="todos_test")


class TodosSearchTest(unittest.TestCase):
    """Tests for Obsidian-style todo tag discovery."""

    def test_find_tag_matches_supports_inline_and_subtags(self) -> None:
        """Find #todo and #todo/sub while ignoring #todos."""
        todos = load_todos()
        with tempfile.TemporaryDirectory() as root:
            note = Path(root) / "daily.md"
            note.write_text("#todo one\n#todo/work two\n#todos no\n", encoding="utf-8")

            matches = todos["find_tag_matches"](Path(root))

        self.assertEqual([match.text for match in matches], ["#todo one", "#todo/work two"])

    def test_find_tag_matches_supports_frontmatter_tags(self) -> None:
        """Find todo tags in inline and multiline frontmatter."""
        todos = load_todos()
        with tempfile.TemporaryDirectory() as root:
            inline = Path(root) / "inline.md"
            inline.write_text("---\ntags: [todo, other]\n---\n", encoding="utf-8")
            listed = Path(root) / "listed.md"
            listed.write_text("---\ntags:\n  - todo/work\n---\n", encoding="utf-8")

            matches = todos["find_tag_matches"](Path(root))

        self.assertEqual([match.text for match in matches], ["tags: [todo, other]", "- todo/work"])

    def test_find_tag_matches_ignores_fenced_code_blocks(self) -> None:
        """Ignore todo tags inside fenced Markdown code blocks."""
        todos = load_todos()
        with tempfile.TemporaryDirectory() as root:
            note = Path(root) / "daily.md"
            note.write_text("```md\n#todo hidden\n```\n#todo visible\n", encoding="utf-8")

            matches = todos["find_tag_matches"](Path(root))

        self.assertEqual([match.text for match in matches], ["#todo visible"])


class TodosCommandTest(unittest.TestCase):
    """Tests for fzf and editor command construction."""

    def test_fzf_row_uses_obsidian_style_display(self) -> None:
        """Format rows like Obsidian's tags picker display."""
        todos = load_todos()
        match = todos["TagMatch"](Path("/notes/daily.md"), 12, '#todo "buy milk"', "todo")

        self.assertEqual(todos["fzf_row"](match), 'daily [12] #todo "buy milk"\t/notes/daily.md\t12')

    def test_editor_command_uses_visual_editor(self) -> None:
        """Open selected notes with VISUAL before EDITOR."""
        todos = load_todos()
        match = todos["TagMatch"](Path("/notes/daily.md"), 12, "#todo", "todo")

        with patch.dict(os.environ, {"VISUAL": "zed --wait", "EDITOR": "nvim"}, clear=False):
            command = todos["editor_command"](match)

        self.assertEqual(command, ["zed", "--wait", "+12", "/notes/daily.md"])


if __name__ == "__main__":
    unittest.main()
