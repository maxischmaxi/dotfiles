(function () {
  const links = [...document.querySelectorAll("a[href]")]
    .map((a) => a.href)
    .filter((v, i, a) => a.indexOf(v) === i);

  navigator.clipboard.writeText(links.join("\n"));
  console.log(`${links.length} Links in Zwischenablage kopiert`);
})();
