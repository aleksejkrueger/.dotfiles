from __future__ import annotations

import datetime
import inspect
import json
import os
from pathlib import Path
from types import ModuleType
from typing import Any


_NVIM_VARS_FILE_ENV = "NVIM_TMUX_VARS_FILE"
_NVIM_TABLE_PREVIEW_ROWS = 500
_NVIM_JSON_MAX_DEPTH = 6
_NVIM_JSON_MAX_ITEMS = 200
_NVIM_JSON_TEXT_LIMIT = 300
_NVIM_EXCLUDED_NAMES = {
    "In",
    "Out",
    "exit",
    "get_ipython",
    "quit",
}
_NVIM_EXCLUDED_PREFIXES = (
    "__nvim",
    "_nvim",
    "_dh",
    "_i",
    "_ih",
    "_ii",
    "_iii",
    "_oh",
    "_sh",
)
_nvim_initial_names: set[str] = set()


def _nvim_should_include_name(name: str) -> bool:
    """Return whether a namespace name should appear in the variable pane."""

    if name in _NVIM_EXCLUDED_NAMES:
        return False
    if name.startswith("_"):
        return False
    return not name.startswith(_NVIM_EXCLUDED_PREFIXES)


def _nvim_short_text(value: Any, limit: int = 120) -> str:
    """Return a compact single-line representation of a Python value."""

    if isinstance(value, ModuleType):
        text = value.__name__
    else:
        try:
            text = repr(value)
        except Exception as error:
            text = f"<repr failed: {type(error).__name__}>"

    text = " ".join(str(text).split())
    if len(text) > limit:
        return text[: limit - 1] + "."
    return text


def _nvim_safe_file_name(name: str) -> str:
    """Return a filesystem-safe name for a variable snapshot file."""

    safe_name = "".join(character if character.isalnum() or character in "._-" else "_" for character in name)
    return safe_name or "variable"


def _nvim_table_dir(vars_path: Path) -> Path:
    """Return the directory used for table preview files."""

    return vars_path.with_name(f"{vars_path.stem}-tables")


def _nvim_figure_dir(vars_path: Path) -> Path:
    """Return the directory used for figure preview files."""

    return vars_path.with_name(f"{vars_path.stem}-figures")


def _nvim_inspect_dir(vars_path: Path) -> Path:
    """Return the directory used for inspect preview files."""

    return vars_path.with_name(f"{vars_path.stem}-inspect")


def _nvim_json_dir(vars_path: Path) -> Path:
    """Return the directory used for JSON preview files."""

    return vars_path.with_name(f"{vars_path.stem}-json")


def _nvim_table_path(vars_path: Path, name: str) -> Path:
    """Return the table preview path for a variable name."""

    return _nvim_table_dir(vars_path) / f"{_nvim_safe_file_name(name)}.json"


def _nvim_figure_path(vars_path: Path, name: str) -> Path:
    """Return the figure preview path for a variable name."""

    return _nvim_figure_dir(vars_path) / f"{_nvim_safe_file_name(name)}.png"


def _nvim_inspect_path(vars_path: Path, name: str) -> Path:
    """Return the inspect preview path for a variable name."""

    return _nvim_inspect_dir(vars_path) / f"{_nvim_safe_file_name(name)}.json"


def _nvim_json_path(vars_path: Path, name: str) -> Path:
    """Return the JSON preview path for a variable name."""

    return _nvim_json_dir(vars_path) / f"{_nvim_safe_file_name(name)}.json"


def _nvim_short_cell(value: Any, limit: int = 100) -> str:
    """Return a compact display string for one table cell."""

    if value is None:
        return ""

    try:
        text = str(value)
    except Exception as error:
        text = f"<str failed: {type(error).__name__}>"

    text = " ".join(text.split())
    if len(text) > limit:
        return text[: limit - 1] + "."
    return text


def _nvim_shape_text(value: Any) -> str:
    """Return a readable shape string when available."""

    shape = getattr(value, "shape", None)
    return repr(shape) if shape is not None else ""


def _nvim_table_records(value: Any) -> tuple[list[str], list[list[str]]] | None:
    """Return a small table preview for dataframe-like values."""

    if not hasattr(value, "columns") or not hasattr(value, "head"):
        return None

    preview = value.head(_NVIM_TABLE_PREVIEW_ROWS)
    columns = [str(column) for column in getattr(preview, "columns", [])]

    if not columns:
        return None

    if hasattr(preview, "to_dicts"):
        records = preview.to_dicts()
    elif hasattr(preview, "to_dict"):
        records = preview.to_dict(orient="records")
    else:
        return None

    rows = [
        [_nvim_short_cell(record.get(column)) for column in getattr(preview, "columns", [])]
        for record in records
        if isinstance(record, dict)
    ]
    return columns, rows


def _nvim_write_table_snapshot(vars_path: Path, name: str, value: Any) -> str:
    """Write a dataframe-like preview and return its path, if available."""

    table_records = _nvim_table_records(value)
    if table_records is None:
        return ""

    columns, rows = table_records
    table_path = _nvim_table_path(vars_path, name)
    payload = {
        "name": name,
        "type": type(value).__name__,
        "shape": _nvim_shape_text(value),
        "columns": columns,
        "rows": rows,
    }
    tmp_path = table_path.with_suffix(table_path.suffix + ".tmp")

    table_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path.write_text(json.dumps(payload), encoding="utf-8")
    tmp_path.replace(table_path)
    return str(table_path)


def _nvim_json_key(value: Any) -> str:
    """Return a compact JSON object key string."""

    if isinstance(value, str):
        text = value
    else:
        text = _nvim_short_text(value, 120)

    return text[:120]


def _nvim_json_value(value: Any, depth: int = 0, seen: set[int] | None = None) -> Any:
    """Return a bounded JSON-serializable representation of a Python value."""

    if value is None or isinstance(value, (str, bool, int, float)):
        return value
    if isinstance(value, (bytes, bytearray)):
        return _nvim_short_text(value, _NVIM_JSON_TEXT_LIMIT)

    if seen is None:
        seen = set()

    if depth >= _NVIM_JSON_MAX_DEPTH:
        return _nvim_short_text(value, _NVIM_JSON_TEXT_LIMIT)

    if isinstance(value, dict):
        value_id = id(value)
        if value_id in seen:
            return "<cycle>"

        seen.add(value_id)
        try:
            items = list(value.items())
            result = {
                _nvim_json_key(key): _nvim_json_value(item_value, depth + 1, seen)
                for key, item_value in items[:_NVIM_JSON_MAX_ITEMS]
            }
            if len(items) > _NVIM_JSON_MAX_ITEMS:
                result["..."] = f"{len(items) - _NVIM_JSON_MAX_ITEMS} more items"
            return result
        except Exception:
            return _nvim_short_text(value, _NVIM_JSON_TEXT_LIMIT)
        finally:
            seen.discard(value_id)

    if isinstance(value, (list, tuple, set, frozenset)):
        value_id = id(value)
        if value_id in seen:
            return "<cycle>"

        seen.add(value_id)
        try:
            items = list(value)
            result = [
                _nvim_json_value(item, depth + 1, seen)
                for item in items[:_NVIM_JSON_MAX_ITEMS]
            ]
            if len(items) > _NVIM_JSON_MAX_ITEMS:
                result.append(f"... {len(items) - _NVIM_JSON_MAX_ITEMS} more items")
            return result
        except Exception:
            return _nvim_short_text(value, _NVIM_JSON_TEXT_LIMIT)
        finally:
            seen.discard(value_id)

    return _nvim_short_text(value, _NVIM_JSON_TEXT_LIMIT)


def _nvim_write_json_snapshot(vars_path: Path, name: str, value: Any) -> str:
    """Write a dict preview as JSON and return its path, if available."""

    if not isinstance(value, dict):
        return ""

    json_path = _nvim_json_path(vars_path, name)
    payload = {
        "name": name,
        "type": type(value).__name__,
        "data": _nvim_json_value(value),
    }
    tmp_path = json_path.with_suffix(json_path.suffix + ".tmp")

    json_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    tmp_path.replace(json_path)
    return str(json_path)


def _nvim_figure_source(value: Any) -> Any | None:
    """Return an object that can save itself as a figure image."""

    if callable(getattr(value, "savefig", None)):
        return value

    figure = getattr(value, "figure", None)
    if figure is not None and callable(getattr(figure, "savefig", None)):
        return figure

    return None


def _nvim_write_figure_snapshot(vars_path: Path, name: str, value: Any) -> str:
    """Write a figure-like object preview and return its path, if available."""

    figure = _nvim_figure_source(value)
    if figure is None:
        return ""

    figure_path = _nvim_figure_path(vars_path, name)
    tmp_path = figure_path.with_name(figure_path.name + ".tmp.png")

    figure_path.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(tmp_path, bbox_inches="tight", dpi=144)
    tmp_path.replace(figure_path)
    return str(figure_path)


def _nvim_signature_text(value: Any) -> str:
    """Return a best-effort signature string."""

    try:
        return str(inspect.signature(value))
    except (TypeError, ValueError):
        return ""


def _nvim_first_doc_line(value: Any) -> str:
    """Return the first non-empty docstring line."""

    doc = inspect.getdoc(value) or ""
    for line in doc.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def _nvim_member_rows(value: Any, predicate: Any) -> list[dict[str, str]]:
    """Return public member rows for an object or class."""

    rows = []
    for name, member in inspect.getmembers(value):
        if name.startswith("_") or not predicate(member):
            continue

        rows.append(
            {
                "name": name,
                "signature": _nvim_signature_text(member),
                "doc": _nvim_first_doc_line(member),
            }
        )

    return rows[:200]


def _nvim_attribute_rows(value: Any) -> list[dict[str, str]]:
    """Return public non-callable attribute rows."""

    rows = []
    for name, member in inspect.getmembers(value):
        if name.startswith("_") or callable(member) or inspect.ismodule(member):
            continue

        rows.append(
            {
                "name": name,
                "type": type(member).__name__,
                "value": _nvim_short_text(member, 160),
            }
        )

    return rows[:200]


def _nvim_bases(value: Any) -> list[str]:
    """Return base class names for classes and instances."""

    class_value = value if isinstance(value, type) else type(value)
    return [base.__name__ for base in getattr(class_value, "__bases__", ()) if base is not object]


def _nvim_inspect_payload(name: str, value: Any) -> dict[str, Any]:
    """Return structured inspect metadata for a class or object."""

    class_value = value if isinstance(value, type) else type(value)
    kind = "class" if isinstance(value, type) else "instance"

    return {
        "name": name,
        "kind": kind,
        "class_name": class_value.__name__,
        "module": getattr(class_value, "__module__", ""),
        "bases": _nvim_bases(value),
        "signature": _nvim_signature_text(value),
        "doc": inspect.getdoc(value) or "",
        "repr": _nvim_short_text(value, 300),
        "attributes": _nvim_attribute_rows(value),
        "methods": _nvim_member_rows(value, callable),
    }


def _nvim_should_inspect(value: Any) -> bool:
    """Return whether a value should get an inspect preview."""

    return isinstance(value, type) or hasattr(value, "__dict__")


def _nvim_write_inspect_snapshot(vars_path: Path, name: str, value: Any) -> str:
    """Write a class/object inspect preview and return its path, if available."""

    if not _nvim_should_inspect(value):
        return ""

    inspect_path = _nvim_inspect_path(vars_path, name)
    tmp_path = inspect_path.with_suffix(inspect_path.suffix + ".tmp")

    inspect_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path.write_text(json.dumps(_nvim_inspect_payload(name, value)), encoding="utf-8")
    tmp_path.replace(inspect_path)
    return str(inspect_path)


def _nvim_remove_stale_snapshots(snapshot_dir: Path, current_paths: set[str], pattern: str) -> None:
    """Remove snapshots that no longer correspond to visible variables."""

    if not snapshot_dir.exists():
        return

    for path in snapshot_dir.glob(pattern):
        if str(path) in current_paths:
            continue

        try:
            path.unlink()
        except OSError:
            pass


def _nvim_detail_text(value: Any) -> str:
    """Return useful size metadata for a Python value when it is available."""

    shape = getattr(value, "shape", None)
    if shape is not None:
        return f"shape={shape!r}"

    try:
        return f"len={len(value)}"
    except Exception:
        return ""


def _nvim_should_include_value(value: Any) -> bool:
    """Return whether a namespace value should appear in the variable pane."""

    return (
        not isinstance(value, ModuleType)
        and not inspect.isfunction(value)
        and not inspect.ismethod(value)
        and not inspect.isbuiltin(value)
    )


def _nvim_variable_rows(namespace: dict[str, Any], vars_path: Path) -> list[dict[str, str]]:
    """Build serializable variable rows from an interactive namespace."""

    rows = []
    table_paths = set()
    figure_paths = set()
    json_paths = set()
    inspect_paths = set()

    for name, value in sorted(namespace.items()):
        if name in _nvim_initial_names:
            continue
        if not _nvim_should_include_name(name):
            continue
        if not _nvim_should_include_value(value):
            continue

        try:
            table_path = _nvim_write_table_snapshot(vars_path, name, value)
        except Exception:
            table_path = ""
        if table_path:
            table_paths.add(table_path)

        try:
            figure_path = _nvim_write_figure_snapshot(vars_path, name, value)
        except Exception:
            figure_path = ""
        if figure_path:
            figure_paths.add(figure_path)

        try:
            json_path = _nvim_write_json_snapshot(vars_path, name, value)
        except Exception:
            json_path = ""
        if json_path:
            json_paths.add(json_path)

        try:
            inspect_path = _nvim_write_inspect_snapshot(vars_path, name, value)
        except Exception:
            inspect_path = ""
        if inspect_path:
            inspect_paths.add(inspect_path)

        viewer_kind = ""
        viewer_path = ""
        if figure_path:
            viewer_kind = "figure"
            viewer_path = figure_path
        elif table_path:
            viewer_kind = "table"
            viewer_path = table_path
        elif json_path:
            viewer_kind = "json"
            viewer_path = json_path
        elif inspect_path:
            viewer_kind = "inspect"
            viewer_path = inspect_path

        rows.append(
            {
                "name": name,
                "type": type(value).__name__,
                "detail": _nvim_detail_text(value),
                "value": _nvim_short_text(value),
                "viewer_kind": viewer_kind,
                "viewer_path": viewer_path,
            }
        )

    _nvim_remove_stale_snapshots(_nvim_table_dir(vars_path), table_paths, "*.json")
    _nvim_remove_stale_snapshots(_nvim_figure_dir(vars_path), figure_paths, "*.png")
    _nvim_remove_stale_snapshots(_nvim_json_dir(vars_path), json_paths, "*.json")
    _nvim_remove_stale_snapshots(_nvim_inspect_dir(vars_path), inspect_paths, "*.json")
    return rows


def _nvim_write_vars_snapshot(namespace: dict[str, Any]) -> None:
    """Write the current namespace snapshot to the configured JSON file."""

    vars_file = os.environ.get(_NVIM_VARS_FILE_ENV)
    if not vars_file:
        return

    path = Path(vars_file)
    payload = {
        "updated_at": datetime.datetime.now().strftime("%H:%M:%S"),
        "vars": _nvim_variable_rows(namespace, path),
    }
    tmp_path = path.with_suffix(path.suffix + ".tmp")

    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path.write_text(json.dumps(payload), encoding="utf-8")
    tmp_path.replace(path)


def _nvim_post_run_cell(_: Any) -> None:
    """Write a variable snapshot after IPython finishes a cell."""

    shell = get_ipython()  # type: ignore[name-defined]
    _nvim_write_vars_snapshot(shell.user_ns)


def _nvim_install_ipython_hook() -> None:
    """Install the IPython post-cell hook used by the tmux vars pane."""

    global _nvim_initial_names

    shell = get_ipython()  # type: ignore[name-defined]
    if shell is None:
        return

    _nvim_initial_names = set(shell.user_ns)
    shell.events.register("post_run_cell", _nvim_post_run_cell)
    _nvim_write_vars_snapshot(shell.user_ns)


_nvim_install_ipython_hook()
