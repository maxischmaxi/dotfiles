# Claude Code config (~/.claude)

Wird von `stow` nach `~/.claude` verlinkt. `~/.claude` bleibt dabei ein echtes
Verzeichnis — nur die hier getrackten Dateien werden Symlinks, alles andere
(Sessions, Plugins-Cache, Credentials, History) bleibt lokal und ungetrackt.

## Inhalt

| Pfad | Zweck |
| --- | --- |
| `CLAUDE.md` | Globale Rules für alle Projekte |
| `settings.json` | Hooks, Plugins, Marketplaces, UI-Prefs |
| `hooks/review-plan.mjs` | `PreToolUse:ExitPlanMode` — lässt jeden Plan von einem zweiten Modell reviewen |
| `hooks/prune-review-sessions.mjs` | `SessionStart` — räumt die pi-Sessions des Plan-Reviewers auf (max. 7 Tage, throttled auf 24 h) |
| `hooks/context-mode-cache-heal.mjs` | `SessionStart` — repariert den kaputten `CLAUDE_PLUGIN_ROOT` des context-mode-Plugins nach einem Auto-Update (anthropics/claude-code#46915) |
| `commands/mr-description.md` | `/mr-description` — MR-Beschreibung für GitLab/GitHub |
| `sounds/` | Benachrichtigungston für den `Stop`-Hook + Generator-Script |
| `token-reporter/` | Eigenes Plugin: meldet Token-Verbrauch pro Projekt an eine REST-API (siehe eigenes README) |
| `skills/bevy`, `skills/bevy-0-19` | Bevy-Skills |

Die übrigen Skills unter `~/.claude/skills/` sind Symlinks in ein separates Repo
(`maxischmaxi/skills`) und werden hier bewusst nicht getrackt.

## Abhängigkeiten

Ohne die hier gelistete Software laufen einzelne Hooks ins Leere. Alle Hooks
sind so gebaut, dass sie eine Session niemals blockieren — fehlt eine
Abhängigkeit, passiert schlicht nichts.

| Hook | Braucht |
| --- | --- |
| `review-plan.mjs` | `pi` CLI im PATH + Zugriff auf das in der Datei gesetzte `MODEL` |
| `prune-review-sessions.mjs` | nichts (räumt `~/.pi/agent/sessions` auf) |
| PostToolUse-Formatter | `npx` / `prettier`, greift nur in Repos mit `.prettierrc*` bzw. `prettier.config.*` |
| Stop-Sound | `mpg123` |

## Setup auf einer neuen Maschine

```bash
mkdir -p ~/.claude
cd ~/dotfiles && stow .
```

`~/.claude` vorher anzulegen ist wichtig: existiert das Verzeichnis nicht,
verlinkt stow es als Ganzes und alle Laufzeitdaten von Claude Code landen
danach im Repo. Aus demselben Grund steht `--no-folding` in der `.stowrc`.

## Fallstricke

**Pfade in `settings.json`.** Hook-Commands laufen über die Shell, deshalb
stehen dort `$HOME/...` statt absoluter Pfade. Wer den Pfad ändert, muss das
Quoting mitziehen.

**Claude Code schreibt selbst in `settings.json`** (Theme, Effort-Level,
`enabledPlugins`, Marketplaces). Solange die Datei über den Symlink geschrieben
wird, landen diese Änderungen direkt im Repo. Falls Claude Code irgendwann
atomar schreibt (temp + rename), wird der Symlink dabei durch eine echte Datei
ersetzt und das Repo läuft still leer. Prüfen mit:

```bash
ls -l ~/.claude/settings.json
```

Zeigt das keinen Symlink mehr, Datei zurück ins Repo kopieren und neu stowen.

**Nicht getrackt und niemals einchecken:** `.credentials.json`, `~/.claude.json`,
`history.jsonl`, `projects/` (inkl. Memory), `sessions/`, `security/`, `plans/`,
`tasks/`, `file-history/`, `shell-snapshots/`, `context-mode/`, `plugins/`,
`logs/`. Das Repo ist public.
