#!/usr/bin/env node

// Deletes pi sessions created by review-plan.mjs once they age out.
// Only sessions whose session_info carries SESSION_NAME are touched; the
// user's own pi sessions are never considered. Runs from SessionStart, so it
// must stay quiet and must never fail in a way that disturbs a Claude start.

import { existsSync, mkdirSync, openSync, readSync, closeSync } from "node:fs";
import { appendFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve, sep } from "node:path";

const SESSION_NAME = "claude-code-plan-review";
const MAX_AGE_DAYS = 7;
const THROTTLE_HOURS = 24;
// session_info sits at the top of the file; never read a whole 76 MB session.
const HEADER_BYTES = 64 * 1024;
const MAX_LOG_BYTES = 256 * 1024;

const dryRun = process.argv.includes("--dry-run");
const verbose = process.argv.includes("--verbose") || dryRun;

const sessionRoot = resolve(
  process.env.PLAN_REVIEW_SESSION_DIR || join(homedir(), ".pi/agent/sessions"),
);
const stateDir = process.env.PLAN_REVIEW_STATE_DIR || join(homedir(), ".claude");
const stampFile = join(stateDir, ".prune-review-sessions-stamp");
const logFile = join(stateDir, "logs", "prune-review-sessions.log");

const maxAgeDays = Number.parseFloat(
  process.env.PLAN_REVIEW_MAX_AGE_DAYS ?? `${MAX_AGE_DAYS}`,
);
const maxAgeMs =
  (Number.isFinite(maxAgeDays) && maxAgeDays >= 0 ? maxAgeDays : MAX_AGE_DAYS) *
  86_400_000;

function say(message) {
  if (verbose) process.stderr.write(`${message}\n`);
}

async function log(message) {
  try {
    mkdirSync(join(stateDir, "logs"), { recursive: true });
    let prefix = "";
    try {
      if ((await stat(logFile)).size > MAX_LOG_BYTES) {
        await rm(logFile, { force: true });
        prefix = "(log truncated)\n";
      }
    } catch {
      // No log yet.
    }
    await appendFile(
      logFile,
      `${prefix}${new Date().toISOString()} ${message}\n`,
      "utf8",
    );
  } catch {
    // Logging must never break the hook.
  }
}

// Reading only the head keeps this cheap even next to multi-megabyte sessions.
function isReviewerSession(file) {
  let fd;
  try {
    fd = openSync(file, "r");
    const buffer = Buffer.alloc(HEADER_BYTES);
    const bytes = readSync(fd, buffer, 0, HEADER_BYTES, 0);
    const head = buffer.subarray(0, bytes).toString("utf8");
    return head
      .split("\n")
      .some(
        (line) =>
          line.includes('"type":"session_info"') &&
          line.includes(`"name":${JSON.stringify(SESSION_NAME)}`),
      );
  } catch {
    return false;
  } finally {
    if (fd !== undefined) {
      try {
        closeSync(fd);
      } catch {
        // Already gone.
      }
    }
  }
}

async function collectSessions(dir, found = []) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return found;
  }
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) await collectSessions(path, found);
    else if (entry.isFile() && entry.name.endsWith(".jsonl")) found.push(path);
  }
  return found;
}

// Guard against ever deleting outside the session root.
function insideSessionRoot(path) {
  const target = resolve(path);
  return target === sessionRoot || target.startsWith(sessionRoot + sep);
}

async function throttled() {
  if (process.env.PLAN_REVIEW_FORCE_PRUNE === "1" || dryRun) return false;
  try {
    const age = Date.now() - (await stat(stampFile)).mtimeMs;
    return age < THROTTLE_HOURS * 3_600_000;
  } catch {
    return false;
  }
}

async function main() {
  if (!existsSync(sessionRoot)) return;
  if (await throttled()) {
    say("skipped: ran less than 24h ago");
    return;
  }
  if (!dryRun) {
    try {
      mkdirSync(stateDir, { recursive: true });
      await writeFile(stampFile, new Date().toISOString(), "utf8");
    } catch {
      // A missing stamp only means we check again next start.
    }
  }

  const cutoff = Date.now() - maxAgeMs;
  const sessions = await collectSessions(sessionRoot);
  let removed = 0;
  let bytes = 0;

  for (const file of sessions) {
    if (!insideSessionRoot(file)) continue;
    let info;
    try {
      info = await stat(file);
    } catch {
      continue;
    }
    if (info.mtimeMs >= cutoff) continue;
    if (!isReviewerSession(file)) continue;

    removed += 1;
    bytes += info.size;
    say(`${dryRun ? "would delete" : "deleting"} ${file} (${info.size} B)`);
    if (dryRun) continue;

    try {
      await rm(file, { force: true });
      // Sub-run transcripts live in a directory named after the session file.
      const sidecar = file.replace(/\.jsonl$/, "");
      if (insideSessionRoot(sidecar) && existsSync(sidecar)) {
        await rm(sidecar, { recursive: true, force: true });
      }
    } catch (error) {
      await log(`failed to delete ${file}: ${error.message}`);
      removed -= 1;
      bytes -= info.size;
    }
  }

  const summary = `${dryRun ? "[dry-run] " : ""}scanned ${sessions.length}, removed ${removed} reviewer session(s), ${(bytes / 1024).toFixed(1)} KB, older than ${maxAgeDays} day(s)`;
  say(summary);
  if (removed > 0 && !dryRun) await log(summary);
}

// Drain stdin so the hook payload never blocks the writer, then always exit 0.
process.stdin.resume();
process.stdin.on("data", () => {});
main()
  .catch(async (error) => {
    await log(`unexpected failure: ${error?.message ?? error}`);
  })
  .finally(() => {
    process.exit(0);
  });
