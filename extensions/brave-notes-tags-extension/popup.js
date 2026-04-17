const HELPER_URL = "http://127.0.0.1:8765";
const CACHE_KEY = "notesCache";

const elements = {
  refresh: document.querySelector("#refresh"),
  checkServer: document.querySelector("#check-server"),
  folderStatus: document.querySelector("#folder-status"),
  indexStatus: document.querySelector("#index-status"),
  tmuxStatus: document.querySelector("#tmux-status"),
  dailyNoteDate: document.querySelector("#daily-note-date"),
  dailyNoteStatus: document.querySelector("#daily-note-status"),
  openDailyFile: document.querySelector("#open-daily-file"),
  openDailyNvim: document.querySelector("#open-daily-nvim"),
  tagQuery: document.querySelector("#tag-query"),
  createdWithinDays: document.querySelector("#created-within-days"),
  clearQuery: document.querySelector("#clear-query"),
  resultsSummary: document.querySelector("#results-summary"),
  results: document.querySelector("#results"),
  resultTemplate: document.querySelector("#result-template"),
  tagCloud: document.querySelector("#tag-cloud")
};

let notesIndex = [];
let activeTags = [];
let helperRootPath = "";
let searchMode = "or";
let defaultTmuxSession = "";

document.addEventListener("DOMContentLoaded", async () => {
  wireEvents();
  setDefaultDailyDate();
  focusSearchInput();
  await loadCachedNotes();
  render();
  await checkHelper(true);
  focusSearchInput();
});

function wireEvents() {
  elements.refresh.addEventListener("click", refreshNotes);
  elements.checkServer.addEventListener("click", () => checkHelper(true));
  elements.createdWithinDays.addEventListener("input", render);
  elements.dailyNoteDate.addEventListener("input", renderDailyNoteStatus);

  elements.openDailyFile.addEventListener("click", async () => {
    const note = getDailyNote();
    if (!note) {
      setStatus("No daily note found for that date.", true);
      return;
    }
    await openNote(note);
  });

  elements.openDailyNvim.addEventListener("click", async () => {
    const note = getDailyNote();
    if (!note) {
      setStatus("No daily note found for that date.", true);
      return;
    }
    await openInTmux(note);
  });

  elements.clearQuery.addEventListener("click", () => {
    elements.tagQuery.value = "";
    elements.createdWithinDays.value = "";
    syncActiveTagsFromInput();
    render();
  });

  elements.tagQuery.addEventListener("input", () => {
    syncActiveTagsFromInput();
    render();
  });
}

function setDefaultDailyDate() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  elements.dailyNoteDate.value = `${year}-${month}-${day}`;
}

function focusSearchInput() {
  elements.tagQuery.focus();
  elements.tagQuery.select();
}

async function checkHelper(loadNotesAfterCheck = true) {
  setStatus("Checking helper...");
  try {
    const response = await fetch(`${HELPER_URL}/health`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const payload = await response.json();
    helperRootPath = payload.root_path || "";
    applyTmuxState(payload.tmux);
    elements.folderStatus.textContent = helperRootPath
      ? `Helper root: ${helperRootPath}`
      : "Helper is running.";
    setStatus("Helper is reachable.");
    if (loadNotesAfterCheck) {
      await refreshNotes();
    }
  } catch (error) {
    render();
    elements.folderStatus.textContent = "Helper offline.";
    defaultTmuxSession = "";
    renderTmuxStatus();
    setStatus("Helper offline. Showing cached notes if available.", true);
  }
}

async function refreshNotes() {
  setStatus("Loading notes from helper...");
  try {
    const response = await fetch(`${HELPER_URL}/notes`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const payload = await response.json();
    helperRootPath = payload.root_path || helperRootPath;
    notesIndex = Array.isArray(payload.notes) ? payload.notes : [];
    await chrome.storage.local.set({
      [CACHE_KEY]: {
        rootPath: helperRootPath,
        notes: notesIndex,
        savedAt: Date.now()
      }
    });
    elements.folderStatus.textContent = helperRootPath
      ? `Helper root: ${helperRootPath}`
      : "Helper is running.";
    setStatus(`Loaded ${notesIndex.length} notes.`);
    render();
  } catch (error) {
    render();
    setStatus(`Could not load notes: ${error.message}`, true);
  }
}

function applyTmuxState(tmuxPayload) {
  defaultTmuxSession = String(tmuxPayload?.default_session || "");
  renderTmuxStatus();
}

function renderTmuxStatus() {
  elements.tmuxStatus.textContent = defaultTmuxSession
    ? `New tmux window opens in ${defaultTmuxSession} with nvim.`
    : "No tmux session found. Start tmux or launch the helper with --tmux-session.";
}

async function loadCachedNotes() {
  const stored = await chrome.storage.local.get([CACHE_KEY]);
  const cache = stored[CACHE_KEY];
  if (!cache) {
    return;
  }
  helperRootPath = cache.rootPath || "";
  notesIndex = Array.isArray(cache.notes) ? cache.notes : [];
  if (helperRootPath) {
    elements.folderStatus.textContent = `Cached root: ${helperRootPath}`;
  }
  if (notesIndex.length > 0) {
    setStatus(`Loaded ${notesIndex.length} cached notes.`);
  }
}

function syncActiveTagsFromInput() {
  const rawValue = elements.tagQuery.value.trim();
  if (!rawValue) {
    activeTags = [];
    searchMode = "or";
    return;
  }

  if (rawValue.includes("+")) {
    searchMode = "and";
  } else {
    searchMode = "or";
  }

  const pieces = searchMode === "and"
    ? rawValue.split("+")
    : rawValue.split(",");
  activeTags = [...new Set(pieces.map((piece) => piece.trim().toLowerCase()).filter(Boolean))];
}

function getTimestamp(value) {
  if (!value) {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function matchesCreatedWithinDays(timestamp, daysValue) {
  const parsedDays = Number.parseInt(daysValue, 10);
  if (!Number.isFinite(parsedDays) || parsedDays <= 0) {
    return true;
  }
  if (timestamp === null) {
    return false;
  }
  const threshold = Date.now() - parsedDays * 24 * 60 * 60 * 1000;
  return timestamp >= threshold;
}

function filterNotes() {
  return notesIndex.filter((note) => {
    const matchesTags = activeTags.length === 0
      ? true
      : searchMode === "and"
        ? activeTags.every((tag) => note.tags.includes(tag))
        : activeTags.some((tag) => note.tags.includes(tag));

    if (!matchesTags) {
      return false;
    }

    const metadata = note.metadata || {};
    const createdAt = getTimestamp(metadata.created_at);
    return matchesCreatedWithinDays(createdAt, elements.createdWithinDays.value);
  });
}

function collectTopTags(limit = 24) {
  const counts = new Map();
  for (const note of notesIndex) {
    for (const tag of note.tags) {
      counts.set(tag, (counts.get(tag) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1] || left[0].localeCompare(right[0]))
    .slice(0, limit);
}

function getDailyNote() {
  const selectedDate = elements.dailyNoteDate.value;
  if (!selectedDate) {
    return null;
  }

  return notesIndex.find((note) => {
    const relativePath = String(note.relative_path || "");
    const basename = relativePath.split("/").pop() || "";
    const stem = basename.replace(/\.[^.]+$/, "");
    return note.title === selectedDate || stem === selectedDate;
  }) || null;
}

function render() {
  renderTagCloud();
  renderResults();
  renderDailyNoteStatus();
}

function renderDailyNoteStatus() {
  const note = getDailyNote();
  const hasSelection = Boolean(note);
  elements.openDailyFile.disabled = !hasSelection;
  elements.openDailyNvim.disabled = !hasSelection;

  if (!elements.dailyNoteDate.value) {
    elements.dailyNoteStatus.textContent = "Pick a day to open that daily note.";
    return;
  }

  elements.dailyNoteStatus.textContent = note
    ? `Daily note: ${note.relative_path}`
    : `No daily note found for ${elements.dailyNoteDate.value}.`;
}

function renderTagCloud() {
  const topTags = collectTopTags();
  elements.tagCloud.innerHTML = "";
  for (const [tag, count] of topTags) {
    const chip = document.createElement("button");
    chip.className = `tag-chip${activeTags.includes(tag) ? " active" : ""}`;
    chip.textContent = `${tag} (${count})`;
    chip.addEventListener("click", () => {
      if (activeTags.includes(tag)) {
        activeTags = activeTags.filter((value) => value !== tag);
      } else {
        activeTags = [...activeTags, tag].sort();
      }
      searchMode = "and";
      elements.tagQuery.value = activeTags.join(" + ");
      render();
    });
    elements.tagCloud.appendChild(chip);
  }
}

function formatDate(value) {
  if (!value) {
    return "n/a";
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return "n/a";
  }
  return parsed.toLocaleString([], {
    dateStyle: "medium",
    timeStyle: "short"
  });
}

function formatBytes(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return "n/a";
  }
  if (value < 1024) {
    return `${value} B`;
  }
  if (value < 1024 * 1024) {
    return `${(value / 1024).toFixed(1)} KB`;
  }
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}

async function openInTmux(note) {
  try {
    setStatus(`Opening ${note.title} in nvim...`);
    const response = await fetch(`${HELPER_URL}/tmux/open`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        path: note.relative_path
      })
    });
    let payload = {};
    try {
      payload = await response.json();
    } catch {
      payload = {};
    }
    if (!response.ok) {
      throw new Error(payload.error || `HTTP ${response.status}`);
    }
    const session = payload.session || defaultTmuxSession;
    setStatus(`Opened ${note.title} in tmux session ${session}.`);
  } catch (error) {
    setStatus(`Could not open in tmux: ${error.message}`, true);
  }
}

async function openNote(note) {
  if (!note.file_url) {
    setStatus("This note has no file:/// URL from the helper.", true);
    return;
  }
  await chrome.tabs.create({ url: note.file_url });
}

function renderResults() {
  const results = filterNotes();
  elements.resultsSummary.textContent = `${results.length} note${results.length === 1 ? "" : "s"}`;
  elements.results.innerHTML = "";

  if (results.length === 0) {
    const emptyState = document.createElement("div");
    emptyState.className = "empty-state";
    emptyState.textContent = notesIndex.length === 0
      ? "No notes loaded yet."
      : "No notes matched those filters.";
    elements.results.appendChild(emptyState);
    return;
  }

  for (const note of results) {
    const fragment = elements.resultTemplate.content.cloneNode(true);
    fragment.querySelector(".result-title").textContent = note.title;
    fragment.querySelector(".result-path").textContent = note.relative_path;
    fragment.querySelector(".result-preview").textContent = note.preview;

    const metadata = note.metadata || {};
    fragment.querySelector(".result-meta").textContent =
      `Created ${formatDate(metadata.created_at)} | Size ${formatBytes(metadata.size_bytes)}`;

    const tagsNode = fragment.querySelector(".result-tags");
    for (const tag of note.tags) {
      const chip = document.createElement("button");
      chip.className = "tag-chip";
      chip.textContent = tag;
      chip.addEventListener("click", (event) => {
        event.stopPropagation();
        if (activeTags.includes(tag)) {
          activeTags = activeTags.filter((value) => value !== tag);
        } else {
          activeTags = [...activeTags, tag].sort();
        }
        searchMode = "and";
        elements.tagQuery.value = activeTags.join(" + ");
        render();
      });
      tagsNode.appendChild(chip);
    }

    fragment.querySelector(".open-note").addEventListener("click", async (event) => {
      event.stopPropagation();
      await openNote(note);
    });

    const tmuxButton = fragment.querySelector(".open-in-tmux");
    tmuxButton.title = defaultTmuxSession
      ? `Open in nvim via tmux session ${defaultTmuxSession}`
      : "Open in nvim via tmux";
    tmuxButton.addEventListener("click", async (event) => {
      event.stopPropagation();
      await openInTmux(note);
    });

    fragment.querySelector(".result-main").addEventListener("click", async () => {
      await openNote(note);
    });

    fragment.querySelector(".result-card").addEventListener("dblclick", async () => {
      await openNote(note);
    });

    fragment.querySelector(".result-card").addEventListener("keydown", async (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        await openNote(note);
      }
    });

    const card = fragment.querySelector(".result-card");
    card.tabIndex = 0;
    card.setAttribute("role", "button");
    card.setAttribute("aria-label", `Open file ${note.title}`);

    elements.results.appendChild(fragment);
  }
}

function setStatus(message, isError = false) {
  elements.indexStatus.textContent = message;
  elements.indexStatus.classList.toggle("muted", !isError);
}
