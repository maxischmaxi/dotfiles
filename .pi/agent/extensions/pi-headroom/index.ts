/**
 * pi-headroom — route pi providers through a shared Headroom proxy.
 *
 * - On session start: starts `headroom proxy` if none is running (reuses an
 *   existing instance otherwise, so every pi talks to the same proxy).
 * - Overrides the baseUrl of the configured providers (default: auto-detected
 *   local OpenAI-completions providers from models.json, e.g. ollama), so all
 *   prompts flow through Headroom and get compressed.
 * - On quit: when the last pi instance goes away, the proxy is stopped.
 *
 * Settings: ~/.pi/agent/extensions/pi-headroom.json
 *   { "enabled": true, "port": 8787, "mode": "cache", "providers": ["ollama"] }
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  HeadroomManager,
  isPidAlive,
  loadConfig,
  resolveRoutedProviders,
  resolveUpstream,
} from "./headroom.ts";

export default function piHeadroom(pi: ExtensionAPI): void {
  const config = loadConfig();
  if (!config.enabled) return;

  const manager = new HeadroomManager(config);
  let sessionBound = false;

  pi.on("session_start", async (_event, ctx) => {
    // session_start fires again for /new, /resume, /fork and /reload; only
    // bind once per pi process.
    if (sessionBound) return;
    sessionBound = true;

    const providers = resolveRoutedProviders(config);
    if (providers.length === 0) {
      ctx.ui.notify(
        "headroom: keine routingfähigen Provider gefunden (openai-completions + loopback baseUrl in models.json) — deaktiviert",
        "warning",
      );
      return;
    }

    try {
      const outcome = await manager.ensureProxy(resolveUpstream(config, providers));
      if (outcome === "failed") {
        ctx.ui.notify(
          `headroom: Proxy konnte nicht gestartet werden (Port ${config.port}) — Provider verbinden direkt`,
          "warning",
        );
        return;
      }

      manager.pruneStaleClients();
      manager.registerClient();

      for (const name of providers) {
        pi.registerProvider(name, { baseUrl: manager.proxyBaseUrl });
      }
    } catch (error) {
      ctx.ui.notify(`headroom: unerwarteter Fehler — ${String(error)}`, "error");
    }
  });

  pi.on("session_shutdown", (event) => {
    if (event.reason !== "quit") return;
    try {
      manager.shutdownIfLast();
    } catch {
      // Never block shutdown.
    }
  });

  // Safety net for exits where no session_shutdown("quit") is emitted.
  process.once("exit", () => {
    manager.syncShutdownIfLast();
  });

  pi.registerCommand("headroom", {
    description: "Headroom-Proxy Status (headroom stop|restart zum Steuern)",
    handler: async (args, ctx) => {
      const cmd = args.trim().toLowerCase();
      const providers = resolveRoutedProviders(config);

      if (cmd === "stop") {
        const clients = manager.liveClientCount();
        if (clients > 1) {
          ctx.ui.notify(`headroom: ${clients - 1} weitere pi-Instanz(en) nutzen den Proxy — stop verweigert`, "warning");
          return;
        }
        const stopped = manager.stopProxy({ waitForExit: true });
        ctx.ui.notify(stopped ? "headroom: Proxy gestoppt" : "headroom: kein Proxy dieser Extension am Laufen", stopped ? "info" : "warning");
        return;
      }

      if (cmd === "restart") {
        manager.stopProxy({ waitForExit: true });
      }

      const healthy = await manager.isHealthy();
      const proxyPid = manager.getProxyPid();
      const lines = [
        `Proxy:      ${healthy ? "läuft" : "gestoppt"} (http://${config.host}:${config.port})`,
        `PID:        ${proxyPid !== undefined ? `${proxyPid}${isPidAlive(proxyPid) ? "" : " (tot)"}` : "extern/nicht von dieser Extension verwaltet"}`,
        `Modus:      ${config.mode}`,
        `Geroutet:   ${providers.length > 0 ? providers.join(", ") : "keine"}`,
        `Pi-Clients: ${manager.liveClientCount()}`,
      ];
      ctx.ui.notify(`headroom:\n${lines.join("\n")}`, "info");
    },
  });
}