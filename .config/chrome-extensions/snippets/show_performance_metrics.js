(function () {
  const perf = performance.getEntriesByType("navigation")[0];
  const paint = performance.getEntriesByType("paint");

  console.table({
    "DOM Content Loaded": `${Math.round(perf.domContentLoadedEventEnd)}ms`,
    "Page Load": `${Math.round(perf.loadEventEnd)}ms`,
    "First Paint": `${Math.round(paint.find((p) => p.name === "first-paint")?.startTime || 0)}ms`,
    "First Contentful Paint": `${Math.round(paint.find((p) => p.name === "first-contentful-paint")?.startTime || 0)}ms`,
  });
})();
