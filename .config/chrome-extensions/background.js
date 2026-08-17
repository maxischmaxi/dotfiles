// Service Worker: stellt den Kontextmenü-Eintrag "Quelltext formatiert anzeigen"
// bereit. Beim Klick wird per scripting.executeScript der Quelltext der aktiven
// Seite eingesammelt (roher fetch-Quelltext + serialisiertes Live-DOM), über
// chrome.storage.session an einen neuen Tab übergeben und dort im Viewer
// (view-source.html) hübsch formatiert dargestellt.
"use strict";

const MENU_ID = "vs-pretty";

// ---- Kontextmenü anlegen ------------------------------------------------

function createMenu() {
  // removeAll vermeidet "duplicate id"-Fehler bei erneutem Registrieren.
  chrome.contextMenus.removeAll(() => {
    void chrome.runtime.lastError;
    chrome.contextMenus.create(
      {
        id: MENU_ID,
        title: "Quelltext formatiert anzeigen",
        contexts: ["page", "frame", "selection", "link", "image"],
        documentUrlPatterns: ["http://*/*", "https://*/*", "file:///*"],
      },
      () => void chrome.runtime.lastError,
    );
  });
}

chrome.runtime.onInstalled.addListener(createMenu);
chrome.runtime.onStartup.addListener(createMenu);

// ---- Grab-Funktion (läuft im Seitenkontext via executeScript) -----------

// Achtung: wird per .toString() serialisiert in die Seite injiziert – darf
// keine Bezeichner von außerhalb referenzieren. Liefert sowohl den rohen
// (vom Server gelieferten) Quelltext als auch das aktuelle, JS-modifizierte DOM.
async function grabSource() {
  function doctypeString(dt) {
    if (!dt) return "";
    let s = "<!DOCTYPE " + dt.name;
    if (dt.publicId) s += ' PUBLIC "' + dt.publicId + '"';
    else if (dt.systemId) s += " SYSTEM";
    if (dt.systemId) s += ' "' + dt.systemId + '"';
    return s + ">";
  }

  const dt = doctypeString(document.doctype);
  const dom = (dt ? dt + "\n" : "") + document.documentElement.outerHTML;

  let raw = null;
  let rawError = null;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 6000);
    const res = await fetch(location.href, {
      credentials: "include",
      cache: "force-cache",
      redirect: "follow",
      signal: ctrl.signal,
    });
    clearTimeout(timer);
    if (res.ok) raw = await res.text();
    else rawError = "HTTP " + res.status + " " + res.statusText;
  } catch (e) {
    rawError =
      e && e.name === "AbortError"
        ? "Zeitüberschreitung beim Laden des Roh-Quelltexts"
        : String((e && e.message) || e);
  }

  return {
    url: location.href,
    title: document.title || location.href,
    contentType: document.contentType || "",
    dom: dom,
    raw: raw,
    rawError: rawError,
  };
}

// ---- Übergabe an den Viewer ---------------------------------------------

function makeId() {
  return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8);
}

// storage.session ist auf ~10 MB gedeckelt. Bei riesigen Seiten ggf. nur die
// primäre Quelle ablegen, dann notfalls nur einen Hinweis.
async function storeData(key, data) {
  try {
    await chrome.storage.session.set({ [key]: data });
    return;
  } catch (e) {
    void e;
  }
  // 2. Versuch: doppelte Quelle (raw vs. dom) verwerfen.
  const primary = data.raw || data.dom || "";
  const slim = {
    url: data.url,
    title: data.title,
    contentType: data.contentType,
    rawError: data.rawError,
    raw: data.raw ? primary : null,
    dom: data.raw ? null : primary,
    trimmed: true,
  };
  try {
    await chrome.storage.session.set({ [key]: slim });
    return;
  } catch (e) {
    void e;
  }
  // 3. Versuch: nur Metadaten + Größenhinweis.
  await chrome.storage.session.set({
    [key]: {
      url: data.url,
      title: data.title,
      tooBig: true,
      size: primary.length,
    },
  });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== MENU_ID || !tab || tab.id == null) return;

  let data = null;
  try {
    const injected = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: grabSource,
    });
    data = injected && injected[0] && injected[0].result;
  } catch (e) {
    console.error("[view-source] executeScript fehlgeschlagen:", e);
  }

  if (!data) {
    data = {
      url: (tab && tab.url) || "",
      title: (tab && tab.title) || "",
      dom: null,
      raw: null,
      rawError:
        "Der Quelltext konnte nicht ausgelesen werden (geschützte Seite?).",
    };
  }

  const id = makeId();
  await storeData("vsrc:" + id, data);

  await chrome.tabs.create({
    url: chrome.runtime.getURL("view-source.html") + "?id=" + id,
    index: tab.index != null ? tab.index + 1 : undefined,
    active: true,
  });
});
