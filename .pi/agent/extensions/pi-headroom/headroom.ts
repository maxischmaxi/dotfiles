/**
 * Headroom proxy lifecycle management for the pi-headroom extension.
 *
 * Goal: exactly one shared `headroom proxy` instance for all running pi
 * processes, started lazily by the first pi instance and stopped when the
 * last pi instance quits.
 *
 * Cross-process coordination happens through small files in
 * `~/.pi/agent/headroom/`:
 *
 *   proxy.pid        PID of the proxy process (only written by the pi
 *                    instance that spawned the proxy). Absent => the running
 *                    proxy was started externally and is left alone.
 *   proxy.spawn.lock Guard against spawn races between pi instances.
 *   clients/<pid>    One file per connected pi process (refcount).
 *   proxy.log        stderr of the extension-spawned proxy.
 */
import { spawn } from "child_process";
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, readdirSync, rmSync, unlinkSync, writeFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";

export interface HeadroomConfig {
  enabled: boolean;
  host: string;
  port: number;
  mode: "token" | "cache";
  /** pi provider names to route through the proxy. Empty = auto-detect. */
  providers: string[];
  /** Command used to start the proxy. */
  headroomCommand: string;
  /** How long to wait for the proxy to become healthy (ms). */
  startupTimeoutMs: number;
}

const DEFAULTS: HeadroomConfig = {
  enabled: true,
  host: "127.0.0.1",
  port: 8787,
  mode: "cache",
  providers: [],
  headroomCommand: "headroom",
  startupTimeoutMs: 20000,
};

const SPAWN_LOCK_STALE_MS = 10_000;
const HEALTH_POLL_MS = 200;
const SHUTDOWN_TERM_GRACE_MS = 3_000;

export function getAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

function getConfigPath(): string {
  return join(getAgentDir(), "extensions", "pi-headroom.json");
}

export function loadConfig(): HeadroomConfig {
  const config: HeadroomConfig = { ...DEFAULTS };
  try {
    if (existsSync(getConfigPath())) {
      const raw = JSON.parse(readFileSync(getConfigPath(), "utf-8")) as Record<string, unknown>;
      if (typeof raw.enabled === "boolean") config.enabled = raw.enabled;
      if (typeof raw.host === "string") config.host = raw.host;
      if (typeof raw.port === "number") config.port = raw.port;
      if (raw.mode === "token" || raw.mode === "cache") config.mode = raw.mode;
      if (Array.isArray(raw.providers)) {
        config.providers = raw.providers.filter((p): p is string => typeof p === "string");
      }
      if (typeof raw.headroomCommand === "string") config.headroomCommand = raw.headroomCommand;
      if (typeof raw.startupTimeoutMs === "number") config.startupTimeoutMs = raw.startupTimeoutMs;
    }
  } catch {
    // Unreadable config => fall back to defaults rather than breaking pi startup.
  }
  return config;
}

interface ModelsFile {
  providers?: Record<string, {
    api?: string;
    baseUrl?: string;
  }>;
}

function readModelsFile(): ModelsFile {
  try {
    if (existsSync(join(getAgentDir(), "models.json"))) {
      return JSON.parse(readFileSync(join(getAgentDir(), "models.json"), "utf-8")) as ModelsFile;
    }
  } catch {
    // ignore
  }
  return {};
}

function isLoopbackUrl(url: string | undefined): boolean {
  if (!url) return false;
  try {
    const { hostname } = new URL(url);
    return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1" || hostname === "[::1]";
  } catch {
    return false;
  }
}

/**
 * Resolve which pi providers should be routed through the proxy.
 *
 * Explicit config wins. Otherwise auto-detect OpenAI-completions providers
 * pointing at a loopback host (e.g. local ollama) from models.json.
 */
export function resolveRoutedProviders(config: HeadroomConfig): string[] {
  if (config.providers.length > 0) return config.providers;
  const models = readModelsFile();
  const names: string[] = [];
  for (const [name, provider] of Object.entries(models.providers ?? {})) {
    if (provider?.api === "openai-completions" && isLoopbackUrl(provider.baseUrl)) {
      names.push(name);
    }
  }
  return names;
}

/** The upstream URL headroom should forward OpenAI-compatible traffic to. */
export function resolveUpstream(config: HeadroomConfig, routedProviders: string[]): string {
  const models = readModelsFile();
  for (const name of routedProviders) {
    const baseUrl = models.providers?.[name]?.baseUrl;
    if (baseUrl) return baseUrl;
  }
  return "http://127.0.0.1:11434/v1";
}

const DEBUG = process.env.PI_HEADROOM_DEBUG === "1";
const DEBUG_LOG = process.env.PI_HEADROOM_DEBUG_LOG ?? "/tmp/pi-headroom-debug.log";

function debug(message: string): void {
  if (!DEBUG) return;
  try {
    appendFileSync(DEBUG_LOG, `${new Date().toISOString()} pid=${process.pid} ${message}\n`);
  } catch {
    // never break pi for debug logging
  }
}

export type ProxyOutcome = "started" | "adopted" | "failed";

export class HeadroomManager {
  private readonly config: HeadroomConfig;
  private readonly runtimeDir: string;
  private readonly clientsDir: string;
  private readonly pidFile: string;
  private readonly lockFile: string;
  private readonly logFile: string;

  constructor(config: HeadroomConfig) {
    this.config = config;
    this.runtimeDir = join(getAgentDir(), "headroom");
    this.clientsDir = join(this.runtimeDir, "clients");
    this.pidFile = join(this.runtimeDir, "proxy.pid");
    this.lockFile = join(this.runtimeDir, "proxy.spawn.lock");
    this.logFile = join(this.runtimeDir, "proxy.log");
  }

  /** Base URL pi providers should use to reach the proxy. */
  get proxyBaseUrl(): string {
    return `http://${this.config.host}:${this.config.port}/v1`;
  }

  async isHealthy(): Promise<boolean> {
    try {
      const response = await fetch(`http://${this.config.host}:${this.config.port}/health`, {
        signal: AbortSignal.timeout(2000),
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  private async waitForHealth(timeoutMs: number): Promise<boolean> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (await this.isHealthy()) return true;
      await sleep(HEALTH_POLL_MS);
    }
    return false;
  }

  /**
   * Make sure a healthy proxy is running.
   *
   * - "started": we spawned it (we own its lifecycle)
   * - "adopted": one was already running (another pi instance or the user)
   * - "failed":  nothing reachable within the timeout
   */
  async ensureProxy(upstreamUrl: string): Promise<ProxyOutcome> {
    mkdirSync(this.clientsDir, { recursive: true });

    if (await this.isHealthy()) {
      debug(`ensureProxy: adopted (already healthy)`);
      return "adopted";
    }

    if (!this.acquireSpawnLock()) {
      // Another pi instance is already spawning the proxy.
      debug(`ensureProxy: lock held elsewhere, waiting for health`);
      const healthy = await this.waitForHealth(this.config.startupTimeoutMs);
      debug(`ensureProxy: lock-wait outcome=${healthy ? "adopted" : "failed"}`);
      return healthy ? "adopted" : "failed";
    }

    try {
      if (await this.isHealthy()) return "adopted";

      const logFd = this.openLogFile();
      const child = spawn(
        this.config.headroomCommand,
        ["proxy", "--host", this.config.host, "--port", String(this.config.port), "--mode", this.config.mode],
        {
          detached: true,
          stdio: ["ignore", "ignore", typeof logFd === "number" ? logFd : "ignore"],
          env: {
            ...process.env,
            OPENAI_TARGET_API_URL: upstreamUrl,
            HEADROOM_HOST: this.config.host,
            HEADROOM_PORT: String(this.config.port),
          },
        },
      );
      // The child owns a duplicate of logFd now; drop ours so it does not leak.
      if (typeof logFd === "number") {
        try { closeSync(logFd); } catch { /* already closed */ }
      }
      child.unref();
      if (typeof child.pid === "number") {
        writeFileSync(this.pidFile, `${child.pid}\n`, { mode: 0o600 });
      }

      if (await this.waitForHealth(this.config.startupTimeoutMs)) {
        debug(`ensureProxy: started (pid ${child.pid})`);
        return "started";
      }

      // Startup failed - clean up so a later attempt can retry.
      debug(`ensureProxy: startup timeout, killing pid ${child.pid}`);
      try { child.kill("SIGKILL"); } catch { /* already gone */ }
      rmSync(this.pidFile, { force: true });
      return "failed";
    } finally {
      this.releaseSpawnLock();
    }
  }

  private openLogFile(): number | "ignore" {
    try {
      return openSync(this.logFile, "a");
    } catch {
      return "ignore";
    }
  }

  // ------------------------------------------------------------------
  // Client registry (refcount across pi processes)
  // ------------------------------------------------------------------

  registerClient(): void {
    mkdirSync(this.clientsDir, { recursive: true });
    writeFileSync(
      join(this.clientsDir, `${process.pid}`),
      JSON.stringify({ pid: process.pid, startedAt: Date.now() }),
      { mode: 0o600 },
    );
    debug(`registerClient: ${process.pid}`);
  }

  unregisterClient(): void {
    rmSync(join(this.clientsDir, `${process.pid}`), { force: true });
  }

  /** Remove client files whose pi process no longer exists. */
  pruneStaleClients(): number {
    let removed = 0;
    try {
      for (const entry of readdirSync(this.clientsDir)) {
        const pid = Number.parseInt(entry, 10);
        if (Number.isFinite(pid) && !isPidAlive(pid)) {
          rmSync(join(this.clientsDir, entry), { force: true });
          removed++;
        }
      }
    } catch {
      // clients dir may not exist yet
    }
    return removed;
  }

  liveClientCount(): number {
    this.pruneStaleClients();
    try {
      return readdirSync(this.clientsDir).length;
    } catch {
      return 0;
    }
  }

  // ------------------------------------------------------------------
  // Shutdown
  // ------------------------------------------------------------------

  /**
   * Called when this pi instance quits. Removes our client registration and
   * stops the proxy if we were the last pi instance. Returns true if the
   * proxy was stopped by this call.
   *
   * A proxy without our pid file was started externally (e.g. by the user
   * for other tools) and is intentionally left running.
   */
  shutdownIfLast(): boolean {
    this.unregisterClient();
    const remaining = this.liveClientCount();
    debug(`shutdownIfLast: remaining live clients=${remaining}`);
    if (remaining > 0) {
      // Other pi instances still need the proxy.
      return false;
    }
    const stopped = this.stopProxy({ waitForExit: true });
    debug(`shutdownIfLast: stopped=${stopped}`);
    return stopped;
  }

  /** Synchronous best-effort variant for process "exit" hooks. */
  syncShutdownIfLast(): boolean {
    try {
      this.unregisterClient();
      if (this.liveClientCount() > 0) return false;
      return this.stopProxy({ waitForExit: false });
    } catch {
      return false;
    }
  }

  /**
   * Stop the proxy via SIGTERM (SIGKILL after a grace period). Returns true
   * if a proxy owned by this extension was stopped.
   */
  stopProxy(options: { waitForExit: boolean }): boolean {
    const pid = this.readProxyPid();
    debug(`stopProxy: pid=${pid ?? "none"} waitForExit=${options.waitForExit} live=${options.waitForExit ? this.liveClientCount() : "n/a"}`);
    if (pid === undefined) return false;

    try {
      process.kill(pid, "SIGTERM");
    } catch {
      rmSync(this.pidFile, { force: true });
      return false;
    }
    rmSync(this.pidFile, { force: true });

    if (options.waitForExit) {
      const deadline = Date.now() + SHUTDOWN_TERM_GRACE_MS;
      while (Date.now() < deadline && isPidAlive(pid)) {
        sleepSync(100);
      }
      if (isPidAlive(pid)) {
        try { process.kill(pid, "SIGKILL"); } catch { /* gone */ }
      }
    }
    return true;
  }

  private readProxyPid(): number | undefined {
    try {
      const pid = Number.parseInt(readFileSync(this.pidFile, "utf-8").trim(), 10);
      return Number.isFinite(pid) ? pid : undefined;
    } catch {
      return undefined;
    }
  }

  getProxyPid(): number | undefined {
    return this.readProxyPid();
  }

  // ------------------------------------------------------------------
  // Spawn lock
  // ------------------------------------------------------------------

  private acquireSpawnLock(): boolean {
    mkdirSync(this.runtimeDir, { recursive: true });
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        writeFileSync(this.lockFile, `${process.pid}\n${Date.now()}\n`, { flag: "wx", mode: 0o600 });
        return true;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
        if (this.isSpawnLockStale()) {
          try { unlinkSync(this.lockFile); } catch { /* raced */ }
          continue;
        }
        return false;
      }
    }
    return false;
  }

  private isSpawnLockStale(): boolean {
    try {
      const [pidLine = "", createdAtLine = "0"] = readFileSync(this.lockFile, "utf-8").trim().split("\n");
      const pid = Number.parseInt(pidLine, 10);
      const createdAt = Number.parseInt(createdAtLine, 10);
      if (Number.isFinite(pid) && isPidAlive(pid)) return false;
      return !Number.isFinite(createdAt) || Date.now() - createdAt > SPAWN_LOCK_STALE_MS;
    } catch {
      return true;
    }
  }

  private releaseSpawnLock(): void {
    try { unlinkSync(this.lockFile); } catch { /* already gone */ }
  }
}

export function isPidAlive(pid: number): boolean {
  if (pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === "EPERM";
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function sleepSync(ms: number): void {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}