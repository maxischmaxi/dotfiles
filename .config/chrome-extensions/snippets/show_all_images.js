(function () {
  const images = document.querySelectorAll("img");
  const overlay = document.createElement("div");
  overlay.style.cssText =
    "position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.9);z-index:99999;overflow:auto;padding:20px;display:flex;flex-wrap:wrap;gap:10px;";

  images.forEach((img) => {
    const clone = img.cloneNode();
    clone.style.cssText =
      "max-width:200px;max-height:200px;object-fit:contain;cursor:pointer;";
    clone.onclick = () => window.open(img.src);
    overlay.appendChild(clone);
  });

  overlay.onclick = (e) => {
    if (e.target === overlay) overlay.remove();
  };
  document.body.appendChild(overlay);
  console.log(`${images.length} Bilder gefunden`);
})();
