// Runs at document_start, so this listener registers before any page script.
// Pages block reload by calling preventDefault() on the keydown event;
// stopping propagation here means they never see it, and the browser
// performs its default reload (Shift+Ctrl+R hard reload included).
function isReloadShortcut(e) {
  return (
    e.key === "F5" ||
    ((e.ctrlKey || e.metaKey) && (e.key === "r" || e.key === "R"))
  );
}

window.addEventListener(
  "keydown",
  (e) => {
    if (isReloadShortcut(e)) e.stopImmediatePropagation();
  },
  true
);
