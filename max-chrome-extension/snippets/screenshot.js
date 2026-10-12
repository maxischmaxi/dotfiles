(async function () {
  try {
    console.log("Bitte wähle den Tab/Fenster zum Erfassen...");

    const stream = await navigator.mediaDevices.getDisplayMedia({
      preferCurrentTab: true,
      video: { mediaSource: "screen" },
    });

    const video = document.createElement("video");
    video.srcObject = stream;
    await video.play();

    // Kurz warten damit das Video geladen ist
    await new Promise((r) => setTimeout(r, 100));

    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d").drawImage(video, 0, 0);

    // Stream stoppen
    stream.getTracks().forEach((t) => t.stop());

    // Vorschau & Download
    const overlay = document.createElement("div");
    overlay.style.cssText =
      "position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.9);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;";

    const img = document.createElement("img");
    img.src = canvas.toDataURL("image/png");
    img.style.cssText =
      "max-width:90%;max-height:70%;object-fit:contain;border:2px solid white;";

    const btnContainer = document.createElement("div");
    btnContainer.style.cssText = "display:flex;gap:10px;";

    const downloadBtn = document.createElement("button");
    downloadBtn.textContent = "📥 Download";
    downloadBtn.style.cssText =
      "padding:12px 24px;font-size:16px;cursor:pointer;background:#4CAF50;color:white;border:none;border-radius:8px;";
    downloadBtn.onclick = () => {
      const link = document.createElement("a");
      link.download = `screenshot-${Date.now()}.png`;
      link.href = canvas.toDataURL("image/png");
      link.click();
    };

    const closeBtn = document.createElement("button");
    closeBtn.textContent = "✕ Schließen";
    closeBtn.style.cssText =
      "padding:12px 24px;font-size:16px;cursor:pointer;background:#f44336;color:white;border:none;border-radius:8px;";
    closeBtn.onclick = () => overlay.remove();

    btnContainer.append(downloadBtn, closeBtn);
    overlay.append(img, btnContainer);
    document.body.appendChild(overlay);

    console.log("Screenshot erstellt!");
  } catch (err) {
    console.error("Abgebrochen oder Fehler:", err.message);
  }
})();
