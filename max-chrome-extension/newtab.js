"use strict";

const timeEl = document.getElementById("time");
const dateEl = document.getElementById("date");

const timeFmt = new Intl.DateTimeFormat("de-DE", {
  hour: "2-digit",
  minute: "2-digit",
});
const dateFmt = new Intl.DateTimeFormat("de-DE", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

function render() {
  const now = new Date();
  timeEl.textContent = timeFmt.format(now);
  dateEl.textContent = dateFmt.format(now);
  // re-render right after the next full minute
  setTimeout(render, 60000 - (now.getSeconds() * 1000 + now.getMilliseconds()) + 10);
}

render();

// prepend favicons from chrome's favicon cache (needs "favicon" permission)
for (const link of document.querySelectorAll(".links a")) {
  const url = new URL(chrome.runtime.getURL("/_favicon/"));
  url.searchParams.set("pageUrl", link.href);
  url.searchParams.set("size", "32");
  const img = document.createElement("img");
  img.src = url.href;
  img.alt = "";
  link.prepend(img);
}
