const HELPER_URL = "http://127.0.0.1:8765";

const elements = {
  noteTitle: document.querySelector("#note-title"),
  notePath: document.querySelector("#note-path"),
  tagList: document.querySelector("#tag-list"),
  status: document.querySelector("#status"),
  noteContent: document.querySelector("#note-content"),
  reloadNote: document.querySelector("#reload-note"),
  openRaw: document.querySelector("#open-raw")
};

const params = new URLSearchParams(window.location.search);
const relativePath = params.get("path") || "";

document.addEventListener("DOMContentLoaded", async () => {
  elements.reloadNote.addEventListener("click", loadNote);
  elements.openRaw.addEventListener("click", async () => {
    const note = await fetchNote();
    if (note?.file_url) {
      chrome.tabs.create({ url: note.file_url });
    }
  });
  await loadNote();
});

async function loadNote() {
  if (!relativePath) {
    setStatus("Missing note path.");
    return;
  }

  setStatus("Loading note…");
  const note = await fetchNote();
  if (!note) {
    return;
  }

  elements.noteTitle.textContent = note.title;
  elements.notePath.textContent = note.relative_path;
  renderTags(note.tags || []);
  elements.noteContent.innerHTML = renderMarkdown(note.content || "");
  setStatus("");
}

async function fetchNote() {
  try {
    const response = await fetch(`${HELPER_URL}/note?path=${encodeURIComponent(relativePath)}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    setStatus(`Could not load note: ${error.message}`);
    elements.noteContent.innerHTML = "";
    return null;
  }
}

function renderTags(tags) {
  elements.tagList.innerHTML = "";
  for (const tag of tags) {
    const chip = document.createElement("span");
    chip.className = "tag";
    chip.textContent = tag;
    elements.tagList.appendChild(chip);
  }
}

function setStatus(message) {
  elements.status.textContent = message;
  elements.status.style.display = message ? "block" : "none";
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function renderInline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>')
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*]+)\*/g, "<em>$1</em>");
}

function renderMarkdown(markdown) {
  const lines = markdown.replace(/\r/g, "").split("\n");
  const html = [];
  let inCodeBlock = false;
  let inList = false;
  let codeBuffer = [];

  const flushCode = () => {
    if (!inCodeBlock) {
      return;
    }
    html.push(`<pre><code>${escapeHtml(codeBuffer.join("\n"))}</code></pre>`);
    inCodeBlock = false;
    codeBuffer = [];
  };

  const flushList = () => {
    if (!inList) {
      return;
    }
    html.push("</ul>");
    inList = false;
  };

  for (const line of lines) {
    if (line.startsWith("```")) {
      if (inCodeBlock) {
        flushCode();
      } else {
        flushList();
        inCodeBlock = true;
      }
      continue;
    }

    if (inCodeBlock) {
      codeBuffer.push(line);
      continue;
    }

    const heading = line.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      flushList();
      const level = heading[1].length;
      html.push(`<h${level}>${renderInline(heading[2])}</h${level}>`);
      continue;
    }

    const blockquote = line.match(/^>\s?(.*)$/);
    if (blockquote) {
      flushList();
      html.push(`<blockquote>${renderInline(blockquote[1])}</blockquote>`);
      continue;
    }

    const listItem = line.match(/^[-*]\s+(.*)$/);
    if (listItem) {
      if (!inList) {
        html.push("<ul>");
        inList = true;
      }
      html.push(`<li>${renderInline(listItem[1])}</li>`);
      continue;
    }

    if (!line.trim()) {
      flushList();
      continue;
    }

    flushList();
    html.push(`<p>${renderInline(line)}</p>`);
  }

  flushCode();
  flushList();
  return html.join("");
}
