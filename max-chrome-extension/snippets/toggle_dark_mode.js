(function () {
  const style =
    document.getElementById("__dark_mode__") || document.createElement("style");
  style.id = "__dark_mode__";

  if (style.textContent) {
    style.remove();
    console.log("Dark Mode deaktiviert");
  } else {
    style.textContent =
      "html{filter:invert(1) hue-rotate(180deg);}img,video,picture{filter:invert(1) hue-rotate(180deg);}";
    document.head.appendChild(style);
    console.log("Dark Mode aktiviert");
  }
})();
