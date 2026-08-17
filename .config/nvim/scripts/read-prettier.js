// prints the resolved Prettier config as JSON (or nothing)
const fs = require("fs");

const path = process.argv[2];
try {
  let cfg;
  if (
    path.endsWith(".json") ||
    path.endsWith(".rc") ||
    path.endsWith(".prettierrc")
  ) {
    cfg = JSON.parse(fs.readFileSync(path, "utf8"));
  } else {
    // js / cjs / mjs / yaml via require if transpiled, else try yaml if available
    if (path.endsWith(".yaml") || path.endsWith(".yml")) {
      try {
        const yaml = require("yaml");
        cfg = yaml.parse(fs.readFileSync(path, "utf8"));
      } catch {
        process.exit(0);
      }
    } else {
      // JS-basiert
      // eslint-disable-next-line import/no-dynamic-require, global-require
      cfg = require(path);
    }
  }
  process.stdout.write(JSON.stringify(cfg || {}));
} catch {
  // silent fail
}
