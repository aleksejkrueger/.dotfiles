#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from datetime import datetime, timezone
from urllib.parse import parse_qs, urlparse


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?", re.DOTALL)


def strip_yaml_quotes(value: str) -> str:
    return value.strip().strip("'\"").strip()


def parse_frontmatter(text: str) -> dict:
    result: dict[str, object] = {}
    lines = text.split("\n")
    index = 0
    while index < len(lines):
      line = lines[index]
      if not line.strip():
          index += 1
          continue

      block_list = re.match(r"^([A-Za-z0-9_-]+):\s*$", line)
      if block_list:
          items: list[str] = []
          while index + 1 < len(lines) and re.match(r"^\s*-\s+", lines[index + 1]):
              index += 1
              items.append(strip_yaml_quotes(re.sub(r"^\s*-\s+", "", lines[index])))
          result[block_list.group(1)] = items
          index += 1
          continue

      inline_list = re.match(r"^([A-Za-z0-9_-]+):\s*\[(.*)\]\s*$", line)
      if inline_list:
          items = [
              strip_yaml_quotes(item)
              for item in inline_list.group(2).split(",")
              if strip_yaml_quotes(item)
          ]
          result[inline_list.group(1)] = items
          index += 1
          continue

      scalar = re.match(r"^([A-Za-z0-9_-]+):\s*(.+)\s*$", line)
      if scalar:
          result[scalar.group(1)] = strip_yaml_quotes(scalar.group(2))

      index += 1
    return result


def normalize_tags(raw_tags: object) -> list[str]:
    if raw_tags is None:
        return []
    if isinstance(raw_tags, list):
        values = raw_tags
    else:
        values = [raw_tags]
    return sorted({str(tag).strip().lower() for tag in values if str(tag).strip()})


def iso_timestamp(value: float | None) -> str | None:
    if value is None:
        return None
    return datetime.fromtimestamp(value, tz=timezone.utc).isoformat()


def build_file_metadata(path: Path) -> dict[str, object]:
    stat = path.stat()
    created_at = getattr(stat, "st_birthtime", None)
    if created_at is None:
        created_at = stat.st_ctime
    return {
        "size_bytes": stat.st_size,
        "created_at": iso_timestamp(created_at),
        "modified_at": iso_timestamp(stat.st_mtime),
        "accessed_at": iso_timestamp(stat.st_atime),
    }


def resolve_note_path(root: Path, relative_path: str) -> Path:
    normalized = relative_path.strip().lstrip("/")
    path = (root / normalized).resolve()
    if not path.is_file() or root.resolve() not in path.parents:
        raise FileNotFoundError(relative_path)
    return path


def parse_note(path: Path, root: Path) -> dict:
    raw_text = path.read_text(encoding="utf-8", errors="ignore").replace("\r", "")
    frontmatter_match = FRONTMATTER_RE.match(raw_text)
    frontmatter = parse_frontmatter(frontmatter_match.group(1)) if frontmatter_match else {}
    body = raw_text[frontmatter_match.end() :] if frontmatter_match else raw_text
    relative_path = path.relative_to(root).as_posix()
    title = str(frontmatter.get("title") or path.stem)
    preview = re.sub(r"\s+", " ", body).strip()[:240] or "(empty note)"
    return {
        "title": title,
        "relative_path": relative_path,
        "file_url": path.resolve().as_uri(),
        "preview": preview,
        "tags": normalize_tags(frontmatter.get("tags")),
        "metadata": build_file_metadata(path),
    }


def read_note(root: Path, relative_path: str) -> dict:
    path = resolve_note_path(root, relative_path)

    raw_text = path.read_text(encoding="utf-8", errors="ignore").replace("\r", "")
    frontmatter_match = FRONTMATTER_RE.match(raw_text)
    frontmatter = parse_frontmatter(frontmatter_match.group(1)) if frontmatter_match else {}
    body = raw_text[frontmatter_match.end() :] if frontmatter_match else raw_text
    note = parse_note(path, root)
    note["content"] = body
    note["frontmatter"] = frontmatter
    return note


def scan_notes(root: Path) -> list[dict]:
    notes: list[dict] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".md", ".markdown"}:
            continue
        notes.append(parse_note(path, root))
    notes.sort(key=lambda note: str(note["title"]).lower())
    return notes


def list_tmux_sessions() -> list[str]:
    try:
        result = subprocess.run(
            ["tmux", "list-sessions", "-F", "#{session_name}"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def list_tmux_sessions_detailed() -> list[dict[str, object]]:
    try:
        result = subprocess.run(
            [
                "tmux",
                "list-sessions",
                "-F",
                "#{session_name}\t#{?session_attached,1,0}\t#{session_last_attached}",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return []

    sessions: list[dict[str, object]] = []
    for line in result.stdout.splitlines():
        name, attached, last_attached = (line.split("\t") + ["", "", ""])[:3]
        if not name.strip():
            continue
        try:
            last_attached_value = int(last_attached)
        except ValueError:
            last_attached_value = 0
        sessions.append(
            {
                "name": name.strip(),
                "attached": attached == "1",
                "last_attached": last_attached_value,
            }
        )
    return sessions


def get_tmux_current_session() -> str | None:
    if not os.environ.get("TMUX"):
        return None
    try:
        result = subprocess.run(
            ["tmux", "display-message", "-p", "#S"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None
    session = result.stdout.strip()
    return session or None


def resolve_tmux_session(configured_session: str | None, requested_session: str | None) -> str | None:
    requested = (requested_session or "").strip()
    if requested:
        return requested

    configured = (configured_session or "").strip()
    if configured:
        return configured

    current_session = get_tmux_current_session()
    if current_session:
        return current_session

    sessions = list_tmux_sessions_detailed()
    if not sessions:
        return None

    attached_sessions = [session for session in sessions if session["attached"]]
    candidate_pool = attached_sessions or sessions
    candidate_pool.sort(
        key=lambda session: (
            int(bool(session["attached"])),
            int(session["last_attached"]),
            str(session["name"]),
        ),
        reverse=True,
    )
    return str(candidate_pool[0]["name"])


def open_note_in_tmux(
    root: Path,
    relative_path: str,
    configured_session: str | None,
    requested_session: str | None,
) -> dict[str, object]:
    path = resolve_note_path(root, relative_path)
    resolved_session = resolve_tmux_session(configured_session, requested_session)
    if not resolved_session:
        raise RuntimeError("No tmux session found. Start tmux or launch the helper with --tmux-session.")

    window_name = path.stem[:24] or "note"
    target_session = f"={resolved_session}:"
    try:
        subprocess.run(["tmux", "has-session", "-t", resolved_session], check=True, capture_output=True, text=True)
        subprocess.run(
            ["tmux", "new-window", "-t", target_session, "-n", window_name, "nvim", str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise RuntimeError("tmux is not installed or not available in PATH.") from error
    except subprocess.CalledProcessError as error:
        stderr = (error.stderr or "").strip()
        raise RuntimeError(stderr or f"tmux command failed with exit code {error.returncode}.") from error

    return {
        "ok": True,
        "session": resolved_session,
        "path": relative_path,
        "command": f"nvim {path}",
    }


class NoteRequestHandler(BaseHTTPRequestHandler):
    server_version = "LocalNotesHelper/0.3"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send_json(
                {
                    "ok": True,
                    "root_path": str(self.server.root_path),
                    "note_count": len(scan_notes(self.server.root_path)),
                    "tmux": {
                        "default_session": resolve_tmux_session(self.server.tmux_session, None),
                        "sessions": list_tmux_sessions(),
                    },
                }
            )
            return

        if parsed.path == "/notes":
            self._send_json(
                {
                    "root_path": str(self.server.root_path),
                    "notes": scan_notes(self.server.root_path),
                }
            )
            return

        if parsed.path == "/note":
            query = parse_qs(parsed.query)
            relative_path = query.get("path", [""])[0]
            if not relative_path:
                self._send_json({"error": "missing path"}, status=HTTPStatus.BAD_REQUEST)
                return
            try:
                note = read_note(self.server.root_path, relative_path)
            except FileNotFoundError:
                self._send_json({"error": "note not found"}, status=HTTPStatus.NOT_FOUND)
                return
            self._send_json(note)
            return

        if parsed.path == "/raw":
            query = parse_qs(parsed.query)
            relative_path = query.get("path", [""])[0]
            if not relative_path:
                self._send_json({"error": "missing path"}, status=HTTPStatus.BAD_REQUEST)
                return
            try:
                note = read_note(self.server.root_path, relative_path)
            except FileNotFoundError:
                self._send_json({"error": "note not found"}, status=HTTPStatus.NOT_FOUND)
                return
            encoded = note["content"].encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/markdown; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(encoded)
            return

        if parsed.path == "/tmux/sessions":
            self._send_json(
                {
                    "sessions": list_tmux_sessions(),
                    "default_session": resolve_tmux_session(self.server.tmux_session, None),
                }
            )
            return

        self._send_json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._send_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/tmux/open":
            self._send_json({"error": "not found"}, status=HTTPStatus.NOT_FOUND)
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length) if content_length > 0 else b"{}"
        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json({"error": "invalid json"}, status=HTTPStatus.BAD_REQUEST)
            return

        relative_path = str(payload.get("path") or "").strip()
        requested_session = str(payload.get("session") or "").strip() or None
        if not relative_path:
            self._send_json({"error": "missing path"}, status=HTTPStatus.BAD_REQUEST)
            return

        try:
            result = open_note_in_tmux(
                self.server.root_path,
                relative_path,
                self.server.tmux_session,
                requested_session,
            )
        except FileNotFoundError:
            self._send_json({"error": "note not found"}, status=HTTPStatus.NOT_FOUND)
            return
        except RuntimeError as error:
            self._send_json({"error": str(error)}, status=HTTPStatus.BAD_REQUEST)
            return

        self._send_json(result, status=HTTPStatus.CREATED)

    def log_message(self, format: str, *args) -> None:
        return

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(encoded)

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")


class NoteServer(ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], root_path: Path, tmux_session: str | None):
        super().__init__(server_address, NoteRequestHandler)
        self.root_path = root_path
        self.tmux_session = tmux_session


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read-only local helper for note discovery.")
    parser.add_argument("--root", required=True, help="Root folder containing markdown notes.")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to.")
    parser.add_argument("--port", type=int, default=8765, help="Port to bind to.")
    parser.add_argument("--tmux-session", help="Default tmux session for opening notes in nvim.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root_path = Path(args.root).expanduser().resolve()
    if not root_path.exists() or not root_path.is_dir():
        raise SystemExit(f"Root path does not exist or is not a directory: {root_path}")

    server = NoteServer((args.host, args.port), root_path, args.tmux_session)
    print(f"Serving notes from {root_path} on http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
