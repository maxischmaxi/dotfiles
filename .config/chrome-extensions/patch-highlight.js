// Syntax-Highlighting für rohe .patch / .diff Seiten (GitLab/GitHub etc.)
// Läuft nur auf echten text/plain-Seiten, parst den Patch und hebt jede
// Code-Zeile sprachabhängig mit highlight.js hervor + Diff-Färbung drüber.
// Eingebettete Bilder (GIT binary patch, literal) werden dekodiert und als
// <img> gerendert; übrige Binärdaten werden zu einem Badge zusammengeklappt.
(function () {
  "use strict";

  // Nur den Rohtext-Viewer des Browsers anfassen, keine echten HTML-Seiten.
  if (document.contentType !== "text/plain") return;

  const pre = document.body && document.body.querySelector("pre");
  if (!pre) return;
  const text = pre.textContent;
  if (!text) return;

  const looksLikePatch =
    /(^|\n)diff --git /.test(text) ||
    /(^|\n)@@ -\d/.test(text) ||
    /^From [0-9a-f]{7,40} /.test(text);
  if (!looksLikePatch) return;

  const lines = text.split("\n");
  // Bei riesigen Patches das teure Per-Zeilen-Highlighting abschalten.
  const HEAVY = lines.length > 20000;

  // ---- Helfer -------------------------------------------------------------

  function escapeHtml(s) {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  const EXT_LANG = {
    js: "javascript", mjs: "javascript", cjs: "javascript", jsx: "javascript",
    ts: "typescript", tsx: "typescript", mts: "typescript", cts: "typescript",
    py: "python", pyw: "python", pyi: "python",
    rb: "ruby", rake: "ruby", gemspec: "ruby",
    rs: "rust",
    go: "go",
    java: "java",
    kt: "kotlin", kts: "kotlin",
    c: "c", h: "c",
    cpp: "cpp", cc: "cpp", cxx: "cpp", hpp: "cpp", hh: "cpp", hxx: "cpp",
    cs: "csharp",
    php: "php", phtml: "php",
    swift: "swift",
    m: "objectivec", mm: "objectivec",
    sh: "bash", bash: "bash", zsh: "bash", ksh: "bash",
    lua: "lua",
    pl: "perl", pm: "perl",
    r: "r",
    sql: "sql",
    css: "css", scss: "scss", sass: "scss", less: "less",
    html: "xml", htm: "xml", xml: "xml", svg: "xml", vue: "xml", xhtml: "xml",
    json: "json",
    yml: "yaml", yaml: "yaml",
    toml: "ini", ini: "ini", cfg: "ini", conf: "ini",
    md: "markdown", markdown: "markdown",
    graphql: "graphql", gql: "graphql",
    wasm: "wasm", wat: "wasm",
    vb: "vbnet",
  };

  const IMG_MIME = {
    png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif",
    webp: "image/webp", avif: "image/avif", bmp: "image/bmp", ico: "image/x-icon",
  };

  function baseName(path) {
    return (path || "").split("/").pop() || path || "";
  }
  function extOf(path) {
    const b = baseName(path).toLowerCase();
    const d = b.lastIndexOf(".");
    return d < 0 ? "" : b.slice(d + 1);
  }
  function detectLang(path) {
    if (/^Makefile/i.test(baseName(path))) return "makefile";
    const lang = EXT_LANG[extOf(path)];
    return lang && hljs.getLanguage(lang) ? lang : null;
  }
  function isImageExt(path) {
    return Object.prototype.hasOwnProperty.call(IMG_MIME, extOf(path));
  }
  function imageMime(path) {
    return IMG_MIME[extOf(path)] || "application/octet-stream";
  }

  function hl(code, lang) {
    if (!code) return "";
    if (!HEAVY && lang) {
      try {
        return hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
      } catch (e) {
        /* fällt unten auf escape zurück */
      }
    }
    return escapeHtml(code);
  }

  function parsePath(diffLine) {
    const m = diffLine.match(/ b\/(.*)$/);
    return m ? m[1] : diffLine.replace(/^diff --git /, "");
  }

  function renderMeta(arr) {
    return arr
      .map((l) => {
        let m;
        if ((m = l.match(/^(Subject:)(.*)$/))) {
          return (
            '<span class="phl-mkey">' + escapeHtml(m[1]) + "</span>" +
            '<span class="phl-subject">' + escapeHtml(m[2]) + "</span>"
          );
        }
        if ((m = l.match(/^(From:|Date:|Author:|Committer:|To:|Cc:)(.*)$/))) {
          return '<span class="phl-mkey">' + escapeHtml(m[1]) + "</span>" + escapeHtml(m[2]);
        }
        return escapeHtml(l);
      })
      .join("\n");
  }

  function renderCode(kind, gutter, content, lang) {
    return (
      '<div class="phl-line phl-' + kind + '">' +
      '<span class="phl-gutter">' + gutter + "</span>" +
      '<span class="phl-code hljs">' + hl(content, lang) + "</span>" +
      "</div>"
    );
  }

  // ---- git binary patch ---------------------------------------------------

  // Konsumiert ab "GIT binary patch" den Forward- (+ Reverse-)Block.
  // Liefert den Forward-Block und den Index der ersten nicht-konsumierten Zeile.
  function consumeBinary(start) {
    let i = start + 1;
    const blocks = [];
    while (i < lines.length) {
      const m = lines[i] && lines[i].match(/^(literal|delta) (\d+)$/);
      if (!m) break;
      i++;
      const data = [];
      for (; i < lines.length && lines[i] !== ""; i++) data.push(lines[i]);
      blocks.push({ type: m[1], size: +m[2], data: data });
      if (i < lines.length && lines[i] === "") i++; // Leerzeile nach Block
    }
    return { forward: blocks[0] || null, end: i };
  }

  const imgPayloads = [];
  let imgSeq = 0;

  function renderBinary(path, forward) {
    const isImg = isImageExt(path);
    if (forward && forward.type === "literal" && isImg && forward.data.length) {
      const id = "phl-img-" + imgSeq++;
      imgPayloads.push({ id: id, mime: imageMime(path), path: path, data: forward.data });
      return (
        '<div class="phl-binary phl-image" id="' + id + '">' +
        '<span class="phl-spin">Bild wird dekodiert …</span></div>'
      );
    }
    const icon = isImg ? "🖼" : "📦";
    let note;
    if (isImg && forward && forward.type === "delta") note = "Bild geändert (binäres Delta – keine Vorschau)";
    else if (isImg) note = "Bild (binär)";
    else note = "Binärdatei";
    const sz = forward && forward.size ? " · " + forward.size + " bytes" : "";
    return '<div class="phl-binary"><span class="phl-binicon">' + icon + "</span>" + escapeHtml(note) + sz + "</div>";
  }

  function renderBinaryNotice(path) {
    const isImg = isImageExt(path);
    return (
      '<div class="phl-binary"><span class="phl-binicon">' + (isImg ? "🖼" : "📦") + "</span>" +
      escapeHtml(isImg ? "Bild geändert – keine Bilddaten im Patch" : "Binärdatei geändert") +
      "</div>"
    );
  }

  // ---- Parser -------------------------------------------------------------

  const FILEMETA_RE =
    /^(index |new file mode|deleted file mode|old mode|new mode|similarity index|dissimilarity index|rename from|rename to|copy from|copy to|--- |\+\+\+ )/;

  const out = ['<div class="phl-root">'];
  let metaBuf = [];
  let openFile = false;
  let inHunk = false;
  let lang = null;
  let curPath = null;
  let fileCount = 0;

  function flushMeta() {
    if (metaBuf.length) {
      out.push('<div class="phl-meta">' + renderMeta(metaBuf) + "</div>");
      metaBuf = [];
    }
  }
  function closeFile() {
    if (openFile) {
      out.push("</div>");
      openFile = false;
    }
    inHunk = false;
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (/^diff --git /.test(line)) {
      flushMeta();
      closeFile();
      curPath = parsePath(line);
      lang = detectLang(curPath);
      fileCount++;
      out.push('<div class="phl-file">');
      out.push(
        '<div class="phl-fileheader">' +
          escapeHtml(curPath) +
          (lang ? ' <span class="phl-lang">' + escapeHtml(lang) + "</span>" : "") +
          "</div>"
      );
      openFile = true;
      inHunk = false;
      continue;
    }

    if (/^From [0-9a-f]{7,40} /.test(line)) {
      closeFile();
      metaBuf.push(line);
      continue;
    }

    if (line === "GIT binary patch" && openFile && !inHunk) {
      const res = consumeBinary(i);
      out.push(renderBinary(curPath, res.forward));
      i = res.end - 1;
      continue;
    }

    if (/^Binary files /.test(line) && openFile && !inHunk) {
      out.push(renderBinaryNotice(curPath));
      continue;
    }

    if (openFile && !inHunk && FILEMETA_RE.test(line)) {
      out.push('<div class="phl-filemeta">' + escapeHtml(line) + "</div>");
      continue;
    }

    if (/^@@/.test(line)) {
      if (!openFile) {
        out.push('<div class="phl-file">');
        openFile = true;
      }
      inHunk = true;
      out.push('<div class="phl-hunkheader">' + escapeHtml(line) + "</div>");
      continue;
    }

    if (inHunk) {
      if (/^-- ?$/.test(line)) {
        closeFile();
        metaBuf.push(line);
        continue;
      }
      if (/^\\ /.test(line)) {
        out.push(
          '<div class="phl-line phl-nonewline"><span class="phl-gutter"></span>' +
            '<span class="phl-code">' + escapeHtml(line) + "</span></div>"
        );
        continue;
      }
      const c = line[0];
      if (c === "+") { out.push(renderCode("add", "+", line.slice(1), lang)); continue; }
      if (c === "-") { out.push(renderCode("del", "-", line.slice(1), lang)); continue; }
      if (c === " ") { out.push(renderCode("ctx", " ", line.slice(1), lang)); continue; }
      if (line === "") { out.push(renderCode("ctx", " ", "", lang)); continue; }
      closeFile();
      metaBuf.push(line);
      continue;
    }

    metaBuf.push(line);
  }
  closeFile();
  flushMeta();
  out.push("</div>");

  // ---- Bild-Dekodierung (git-base85 + zlib inflate) -----------------------

  const B85 =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~";
  const B85VAL = new Int16Array(256).fill(-1);
  for (let i = 0; i < B85.length; i++) B85VAL[B85.charCodeAt(i)] = i;

  function b85LineLen(code) {
    if (code >= 65 && code <= 90) return code - 65 + 1; // A-Z => 1..26
    if (code >= 97 && code <= 122) return code - 97 + 27; // a-z => 27..52
    return -1;
  }

  function base85Decode(dataLines) {
    const bytes = [];
    for (const line of dataLines) {
      if (!line) continue;
      let n = b85LineLen(line.charCodeAt(0));
      if (n < 0) continue;
      let p = 1; // Längen-Zeichen überspringen
      while (n > 0) {
        let acc = 0;
        for (let k = 0; k < 5; k++) acc = acc * 85 + B85VAL[line.charCodeAt(p++)];
        acc = acc >>> 0;
        const g = [(acc >>> 24) & 255, (acc >>> 16) & 255, (acc >>> 8) & 255, acc & 255];
        for (let k = 0; k < 4 && n > 0; k++, n--) bytes.push(g[k]);
      }
    }
    return Uint8Array.from(bytes);
  }

  async function inflate(u8) {
    const ds = new DecompressionStream("deflate"); // git nutzt zlib-wrapped deflate
    const stream = new Blob([u8]).stream().pipeThrough(ds);
    const ab = await new Response(stream).arrayBuffer();
    return new Uint8Array(ab);
  }

  async function decodeImage(p) {
    const deflated = base85Decode(p.data);
    const raw = await inflate(deflated);
    return URL.createObjectURL(new Blob([raw], { type: p.mime }));
  }

  const imgCache = new Map();

  function setImg(el, p, url) {
    el.dataset.done = "1";
    el.innerHTML = "";
    const img = document.createElement("img");
    img.className = "phl-img";
    img.loading = "lazy";
    img.alt = p.path || "";
    img.addEventListener("error", () => setBadge(el, p, "Bild konnte nicht dargestellt werden"));
    img.src = url;
    el.appendChild(img);
    const cap = document.createElement("div");
    cap.className = "phl-imgcap";
    cap.textContent = p.path || "";
    el.appendChild(cap);
  }

  function setBadge(el, p, msg) {
    el.dataset.done = "1";
    el.classList.remove("phl-image");
    el.innerHTML = "";
    const span = document.createElement("span");
    span.className = "phl-binicon";
    span.textContent = "🖼";
    el.appendChild(span);
    el.appendChild(document.createTextNode(msg || "Bild (binär)"));
  }

  function hydrateImages() {
    for (const p of imgPayloads) {
      const el = document.getElementById(p.id);
      if (!el || el.dataset.done) continue;
      const cached = imgCache.get(p.id);
      if (cached) {
        setImg(el, p, cached);
        continue;
      }
      decodeImage(p)
        .then((url) => {
          imgCache.set(p.id, url);
          const e = document.getElementById(p.id);
          if (e && !e.dataset.done) setImg(e, p, url);
        })
        .catch(() => {
          const e = document.getElementById(p.id);
          if (e && !e.dataset.done) setBadge(e, p, "Bild konnte nicht dekodiert werden");
        });
    }
  }

  // ---- Rendering + Toolbar-Toggle ----------------------------------------

  function toolbar(mode) {
    const other = mode === "hl" ? "Raw" : "Highlighted";
    return (
      '<div class="phl-toolbar">' +
      '<span class="phl-title">patch</span>' +
      '<span class="phl-count">' + fileCount + (fileCount === 1 ? " Datei" : " Dateien") + "</span>" +
      '<button type="button" data-phl-toggle>' + other + "</button>" +
      "</div>"
    );
  }

  const highlightedHTML = toolbar("hl") + out.join("");
  const rawHTML = toolbar("raw") + '<pre class="phl-raw">' + escapeHtml(text) + "</pre>";

  function render() {
    document.documentElement.classList.add("phl-active");
    document.body.classList.add("phl-body");
    document.body.innerHTML = highlightedHTML;
    hydrateImages();

    let mode = "hl";
    document.body.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-phl-toggle]");
      if (!btn) return;
      mode = mode === "hl" ? "raw" : "hl";
      document.body.innerHTML = mode === "hl" ? highlightedHTML : rawHTML;
      if (mode === "hl") hydrateImages();
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", render);
  } else {
    render();
  }
})();
