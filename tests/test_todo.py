"""Tests for the todo CLI helper."""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


TODO_SCRIPT = Path(__file__).resolve().parents[1] / "src" / "todo"


class TodoCommandTest(unittest.TestCase):
    """Tests for appending todos to vimwiki daily notes."""

    def test_todo_appends_quoted_text_to_today_vimwiki_file(self) -> None:
        """Append the todo text to the default daily vimwiki file."""
        with tempfile.TemporaryDirectory() as home:
            env = os.environ.copy()
            env["HOME"] = home
            env.pop("NOTES", None)

            subprocess.run(
                [str(TODO_SCRIPT), "buy milk"],
                check=True,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            note_files = list((Path(home) / "notes" / "vimwiki").glob("*.md"))
            self.assertEqual(len(note_files), 1)
            note_file = note_files[0]
            note_file_name = note_file.name
            note_text = note_file.read_text()

        self.assertTrue(re.fullmatch(r"\d{4}-\d{2}-\d{2}\.md", note_file_name))
        self.assertEqual(note_text, '#todo "buy milk"\n')

    def test_todo_appends_multiple_entries(self) -> None:
        """Append repeated todos to the bottom of the same daily file."""
        with tempfile.TemporaryDirectory() as home:
            env = os.environ.copy()
            env["HOME"] = home
            env.pop("NOTES", None)

            subprocess.run([str(TODO_SCRIPT), "first"], check=True, env=env)
            subprocess.run([str(TODO_SCRIPT), "second"], check=True, env=env)

            note_file = next((Path(home) / "notes" / "vimwiki").glob("*.md"))
            note_text = note_file.read_text()

        self.assertEqual(note_text, '#todo "first"\n#todo "second"\n')

    def test_todo_requires_text(self) -> None:
        """Reject empty todo invocations with usage text."""
        with tempfile.TemporaryDirectory() as home:
            env = os.environ.copy()
            env["HOME"] = home
            env.pop("NOTES", None)

            completed = subprocess.run(
                [str(TODO_SCRIPT)],
                check=False,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn('usage: todo "text"', completed.stderr)


if __name__ == "__main__":
    unittest.main()
