// Viewer für den formatierten Quelltext. Holt die vom Service Worker in
// chrome.storage.session abgelegten Daten, formatiert sie mit js-beautify
// (handgeschrieben-saubere Einrückung), hebt sie mit highlight.js hervor und
// rendert sie mit Zeilennummern. Bei sehr großen Seiten wird das teure
// Highlighting standardmäßig abgeschaltet, bleibt aber per Klick aktivierbar.
"use strict";

(function () {
  const $ = (id) => document.getElementById(id);
  const els = {
    title: $("vs-title"),
    meta: $("vs-meta"),
    controls: $("vs-controls"),
    gutter: $("vs-gutter"),
    code: $("vs-code"),
    scroll: $("vs-scroll"),
  };

  // Ab hier gilt eine Seite als "schwer": dann ist Highlighting per Default aus.
  const HEAVY_CHARS = 400000;
  const HEAVY_LINES = 12000;
  // Einzelner eingebetteter Block (z. B. ein minifiziertes Inline-Bundle) wird
  // ab dieser Größe nicht gehighlightet – sonst hängt hljs ewig an einer Zeile.
  const HEAVY_SEGMENT = 150000;

  const BEAUTIFY_OPTS = {
    indent_size: 2,
    indent_char: " ",
    wrap_line_length: 0, // keine künstlichen Zeilenumbrüche in Attributlisten
    preserve_newlines: false, // komplett frisch formatieren
    indent_inner_html: true,
    end_with_newline: false,
    extra_liners: [], // keine Leerzeilen vor head/body/html
    indent_scripts: "normal",
    js: { indent_size: 2, end_with_newline: false },
    css: { indent_size: 2, end_with_newline: false },
  };

  const state = {
    data: null,
    mode: "raw", // "raw" | "dom"
    formatted: "",
    lineCount: 0,
    highlight: true,
    wrap: false,
  };

  // ---- Daten holen -------------------------------------------------------

  async function load() {
    const id = new URLSearchParams(location.search).get("id");
    if (!id) return fatal("Keine Quelle angegeben.");
    const key = "vsrc:" + id;

    let data;
    try {
      const got = await chrome.storage.session.get(key);
      data = got[key];
      // Einmal-Übergabe: Schlüssel direkt wieder freigeben.
      chrome.storage.session.remove(key);
    } catch (e) {
      return fatal("Quelltext konnte nicht geladen werden: " + e);
    }
    if (!data) return fatal("Quelltext nicht gefunden (Tab evtl. neu geladen).");
    if (data.tooBig) {
      return fatal(
        "Die Seite ist zu groß für die Übergabe (" +
          formatBytes(data.size || 0) +
          ").",
      );
    }

    state.data = data;
    document.title = "Quelltext – " + (data.title || data.url || "");
    els.title.textContent = data.title || "Quelltext";
    els.title.title = data.url || "";

    // Standardmodus: echter Roh-Quelltext, sonst Live-DOM.
    state.mode = data.raw ? "raw" : "dom";
    render();
  }

  // ---- Formatieren + Rendern --------------------------------------------

  function currentSource() {
    return state.mode === "raw" ? state.data.raw : state.data.dom;
  }

  function format(src) {
    if (typeof window.html_beautify !== "function") return src; // Vendor fehlt
    try {
      return window.html_beautify(src, BEAUTIFY_OPTS);
    } catch (e) {
      console.warn("[view-source] beautify fehlgeschlagen:", e);
      return src;
    }
  }

  function render() {
    const src = currentSource();
    if (src == null) {
      return fatal(
        state.data.rawError || "Für diesen Modus liegt kein Quelltext vor.",
      );
    }

    busy(true);
    // setTimeout, damit der "Formatiere…"-Zustand zuerst gezeichnet wird.
    setTimeout(() => {
      state.formatted = format(src);
      state.lineCount = state.formatted.split("\n").length;

      const heavy =
        state.formatted.length > HEAVY_CHARS || state.lineCount > HEAVY_LINES;
      // Bei schweren Seiten Highlighting einmalig automatisch deaktivieren.
      if (heavy && state._heavyApplied !== state.mode) {
        state.highlight = false;
        state._heavyApplied = state.mode;
      }

      paint();
      buildControls(heavy);
      busy(false);
    }, 0);
  }

  function paint() {
    // Gutter mit Zeilennummern (eine Textnode, performant).
    const n = state.lineCount;
    let g = "";
    for (let i = 1; i <= n; i++) g += i + "\n";
    els.gutter.textContent = g;

    if (state.highlight && window.hljs) {
      try {
        els.code.innerHTML = highlightDocument(state.formatted);
      } catch (e) {
        console.warn("[view-source] highlight fehlgeschlagen:", e);
        els.code.textContent = state.formatted;
      }
    } else {
      els.code.textContent = state.formatted;
    }

    document.body.classList.toggle("vs-wrap", state.wrap);

    const bytes = new TextEncoder().encode(state.formatted).length;
    const parts = [
      n.toLocaleString("de-DE") + (n === 1 ? " Zeile" : " Zeilen"),
      formatBytes(bytes),
      state.mode === "raw" ? "Roh-Quelltext" : "Live-DOM",
    ];
    if (state.data.trimmed) parts.push("gekürzt");
    els.meta.textContent = "· " + parts.join(" · ");
  }

  // ---- Toolbar -----------------------------------------------------------

  function buildControls(heavy) {
    els.controls.textContent = "";

    const hasBoth = state.data.raw != null && state.data.dom != null;
    if (hasBoth) {
      addButton(
        state.mode === "raw" ? "Live-DOM" : "Roh-Quelltext",
        "Quelle umschalten",
        () => {
          state.mode = state.mode === "raw" ? "dom" : "raw";
          render();
        },
      );
    }

    addButton(
      state.highlight ? "Highlighting aus" : "Highlighting an",
      heavy && !state.highlight
        ? "Große Seite – Highlighting kann kurz ruckeln"
        : "Syntax-Highlighting umschalten",
      () => {
        state.highlight = !state.highlight;
        busy(true);
        setTimeout(() => {
          paint();
          buildControls(heavy);
          busy(false);
        }, 0);
      },
    );

    addButton(state.wrap ? "Umbruch aus" : "Umbruch an", "Zeilenumbruch", () => {
      state.wrap = !state.wrap;
      paint();
      buildControls(heavy);
    });

    addButton("Kopieren", "Formatierten Quelltext kopieren", async (btn) => {
      try {
        await navigator.clipboard.writeText(state.formatted);
        flash(btn, "Kopiert ✓");
      } catch (e) {
        flash(btn, "Fehlgeschlagen");
      }
    });

    addButton("Download", "Als .html speichern", () => {
      const blob = new Blob([state.formatted], { type: "text/html" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = fileName(state.data.url);
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 5000);
    });
  }

  function addButton(label, title, onClick) {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    if (title) b.title = title;
    b.addEventListener("click", () => onClick(b));
    els.controls.appendChild(b);
  }

  function flash(btn, text) {
    const old = btn.textContent;
    btn.textContent = text;
    btn.disabled = true;
    setTimeout(() => {
      btn.textContent = old;
      btn.disabled = false;
    }, 1200);
  }

  // ---- Syntax-Highlighting (HTML + eingebettetes JS/CSS) -----------------

  function escapeHtml(s) {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  // Welche Sprache steckt im <script>/<style>-Körper?
  function innerLang(tag, attrs) {
    if (tag === "style") return "css";
    const m = /\btype\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))/i.exec(attrs || "");
    const type = (m ? m[2] || m[3] || m[4] || "" : "").trim().toLowerCase();
    if (
      !type ||
      type === "module" ||
      type === "text/javascript" ||
      type === "application/javascript" ||
      type === "application/x-javascript" ||
      type === "text/ecmascript" ||
      type === "text/babel" ||
      type === "text/jsx"
    ) {
      return "javascript";
    }
    if (type.indexOf("json") !== -1) return "json";
    if (type.indexOf("typescript") !== -1) return "typescript";
    if (type.indexOf("html") !== -1 || type.indexOf("template") !== -1) {
      return "xml";
    }
    return null; // unbekannter Typ -> nur escapen, nicht highlighten
  }

  function highlightSegment(text, lang) {
    if (!text) return "";
    if (
      lang &&
      text.length <= HEAVY_SEGMENT &&
      window.hljs &&
      window.hljs.getLanguage(lang)
    ) {
      try {
        return window.hljs.highlight(text, {
          language: lang,
          ignoreIllegals: true,
        }).value;
      } catch (e) {
        /* fällt unten auf escape zurück */
      }
    }
    return escapeHtml(text);
  }

  // Zerlegt das formatierte Dokument in HTML- / JS- / CSS-Abschnitte und
  // highlightet jeden mit der passenden Grammatik. Es werden nur Teilstrings
  // aneinandergereiht -> Zeilenanzahl bleibt exakt erhalten (Gutter passt).
  function highlightDocument(src) {
    let out = "";
    let last = 0;
    const open = /<(script|style)\b([^>]*)>/gi;
    let m;
    while ((m = open.exec(src))) {
      const tag = m[1].toLowerCase();
      const openEnd = open.lastIndex; // Position direkt hinter dem '>'
      out += highlightSegment(src.slice(last, openEnd), "xml");

      const rest = src.slice(openEnd);
      const cm = new RegExp("</" + tag + "\\s*>", "i").exec(rest);
      const lang = innerLang(tag, m[2]);
      if (!cm) {
        // Kein passender Close-Tag -> Rest als Körper behandeln.
        out += highlightSegment(rest, lang);
        last = src.length;
        break;
      }
      const contentEnd = openEnd + cm.index;
      const closeEnd = contentEnd + cm[0].length;
      out += highlightSegment(src.slice(openEnd, contentEnd), lang);
      out += highlightSegment(src.slice(contentEnd, closeEnd), "xml");
      last = closeEnd;
      open.lastIndex = closeEnd;
    }
    out += highlightSegment(src.slice(last), "xml");
    return out;
  }

  // ---- Helfer ------------------------------------------------------------

  function busy(on) {
    document.body.classList.toggle("vs-busy", on);
  }

  function fatal(msg) {
    busy(false);
    els.meta.textContent = "";
    els.controls.textContent = "";
    els.gutter.textContent = "";
    els.code.textContent = "";
    const div = document.createElement("div");
    div.className = "vs-error";
    div.textContent = msg;
    els.scroll.replaceChildren(div);
  }

  function formatBytes(n) {
    if (n < 1024) return n + " B";
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
    return (n / 1024 / 1024).toFixed(2) + " MB";
  }

  function fileName(url) {
    try {
      const u = new URL(url);
      const last = u.pathname.split("/").filter(Boolean).pop() || u.hostname;
      const base = last.replace(/\.[^.]+$/, "") || "source";
      return base + ".formatted.html";
    } catch (e) {
      return "source.formatted.html";
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", load);
  } else {
    load();
  }
})();
