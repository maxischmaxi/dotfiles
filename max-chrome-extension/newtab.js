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
