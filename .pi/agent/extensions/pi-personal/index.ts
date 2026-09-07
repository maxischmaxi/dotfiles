/**
 * pi-personal — persönliche Pi-Commands.
 *
 * /clear — Alias für /new: startet eine neue Session (alter Verlauf bleibt
 *          als Session-File erhalten, wie bei /new).
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function piPersonal(pi: ExtensionAPI): void {
  pi.registerCommand("clear", {
    description: "Neue Session starten (Alias für /new)",
    handler: async (_args, ctx) => {
      await ctx.newSession();
    },
  });
}