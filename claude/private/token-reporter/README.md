# Project Token Reporter

Ein Claude-Code-Plugin, das den **Token-Verbrauch pro Projekt** an eine selbst gewählte
**REST-API** meldet. Es hängt sich an zwei Lifecycle-Hooks:

- **`Stop`** – feuert nach jedem Assistant-Turn → sendet einen aktuellen Snapshot des
  kumulierten Session-Verbrauchs (läuft `async`, blockiert die Sitzung also nicht).
- **`SessionEnd`** – feuert einmal beim Beenden der Session → sendet den finalen Report
  (`final: true`).

Pro Report ermittelt das Plugin das Projekt (Git-Repo-Name + Remote + Branch, sonst
Verzeichnisname) und summiert die Token aus dem Transcript.

> Ohne gesetzte `TOKEN_REPORTER_URL` ist das Plugin ein **No-Op** – es wird nichts gesendet.

---

## Verzeichnisstruktur

```
token-reporter/
├── .claude-plugin/
│   └── marketplace.json        # lokaler Marketplace (zeigt auf ./plugin)
├── plugin/                     # = CLAUDE_PLUGIN_ROOT
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── hooks/
│   │   └── hooks.json          # Stop- + SessionEnd-Hook (auto-discovered)
│   ├── commands/
│   │   └── status.md           # /token-reporter:status
│   └── scripts/
│       ├── report-tokens.mjs   # die eigentliche Logik (Node, nur Built-ins)
│       └── selftest.mjs        # Unit-Tests (node selftest.mjs)
└── README.md
```

Voraussetzung: **Node.js 18+** muss im `PATH` der Claude-Code-Umgebung liegen
(`fetch` ist eingebaut, keine npm-Dependencies).

---

## Installation

### A) Schnell zum Testen (Dev)

```bash
claude --plugin-dir ~/.claude/token-reporter/plugin
```

### B) Regulär über den lokalen Marketplace

In einer Claude-Code-Sitzung:

```
/plugin marketplace add ~/.claude/token-reporter
/plugin install token-reporter@token-reporter
```

> **Opt-in:** Das Plugin hat `defaultEnabled: false`. Nach dem Install ist es
> **registriert, aber deaktiviert** – die Hooks laufen also erst, wenn du es bewusst
> einschaltest. Damit kannst du es gefahrlos installieren und nur bei Bedarf nutzen.

### Aktivieren, wenn du es brauchst

- In der Sitzung: `/plugin` → Tab *Installed* → `token-reporter` auswählen → *Enable*, danach `/reload-plugins`, **oder**
- in `~/.claude/settings.json`:
  ```json
  { "enabledPlugins": { "token-reporter@token-reporter": true } }
  ```
  (auf `false` setzen oder den Eintrag entfernen = wieder deaktiviert).

Prüfen, dass die Hooks aktiv sind: `/hooks` (Events `Stop` und `SessionEnd` sollten
auftauchen) bzw. `/plugin` → Tab *Installed*.

---

## Konfiguration

Die Konfiguration läuft über Environment-Variablen. Empfohlen: der `env`-Block in
`~/.claude/settings.json`, da diese Variablen an die Hook-Prozesse vererbt werden.

```jsonc
// ~/.claude/settings.json
{
  "env": {
    "TOKEN_REPORTER_URL": "https://meine-api.example.com/usage",
    "TOKEN_REPORTER_TOKEN": "geheimes-bearer-token"
  }
}
```

Alternativ in der Shell (z. B. `~/.config/zshrc.zsh`):

```bash
export TOKEN_REPORTER_URL="https://meine-api.example.com/usage"
export TOKEN_REPORTER_TOKEN="geheimes-bearer-token"
```

| Variable | Pflicht | Default | Bedeutung |
| --- | --- | --- | --- |
| `TOKEN_REPORTER_URL` | ja | – | Ziel-Endpoint (POST). Fehlt sie → No-Op. |
| `TOKEN_REPORTER_TOKEN` | nein | – | Wird als `Authorization: Bearer …` gesendet. |
| `TOKEN_REPORTER_PROJECT` | nein | Git/Verzeichnis | Überschreibt den Projektnamen. |
| `TOKEN_REPORTER_TIMEOUT_MS` | nein | `5000` | HTTP-Timeout in ms. |
| `TOKEN_REPORTER_ON_STOP` | nein | `1` | `0` → keine Snapshots nach jedem Turn. |
| `TOKEN_REPORTER_ON_SESSION_END` | nein | `1` | `0` → kein finaler Report am Session-Ende. |
| `TOKEN_REPORTER_DEBUG` | nein | `0` | `1` → Debug-Log nach `$CLAUDE_PLUGIN_DATA/token-reporter.log` (sonst `$TMPDIR`). |

---

## Payload (POST-Body, JSON)

```json
{
  "client": "claude-code-token-reporter/1.0.0",
  "event": "Stop",
  "final": false,
  "reported_at": "2026-06-03T10:00:00.000Z",
  "session_id": "abc123",
  "cwd": "/home/max/projekt",
  "transcript_path": "~/.claude/projects/.../session.jsonl",
  "end_reason": null,
  "project": {
    "name": "mein-repo",
    "path": "/home/max/projekt",
    "git_remote": "git@github.com:max/mein-repo.git",
    "git_branch": "main"
  },
  "models": ["claude-opus-4-8"],
  "tokens": {
    "input": 1234,
    "output": 5678,
    "cache_creation": 9000,
    "cache_read": 42000,
    "total": 57912,
    "billed_input": 12700,
    "messages": 12
  },
  "turn_tokens": null
}
```

- `tokens.total` = `input + output + cache_creation + cache_read` (rohe Token-Menge).
- `tokens.billed_input` = `input + 0.25·cache_creation + 0.10·cache_read` (gewichtete Input-Token für Kostenschätzungen).
- Bei `event: "SessionEnd"` ist `final: true`; `end_reason` enthält den Grund (`clear`, `logout`, …).
- `event: "ping"` (siehe unten) sendet eine reduzierte Payload nur mit `client`, `event`, `reported_at`, `project`.

**Server-Empfehlung:** Da `Stop` mehrfach pro Session feuert, idealerweise per
`session_id` **upserten** (jeder Snapshot ist kumulativ), und `final: true` als
endgültigen Wert behandeln.

---

## Testen

```bash
# 1) Unit-Tests der reinen Logik (kein Netzwerk)
node ~/.claude/token-reporter/plugin/scripts/selftest.mjs

# 2) Dry-Run gegen ein echtes Transcript (zeigt nur die Payload, sendet NICHTS)
node ~/.claude/token-reporter/plugin/scripts/report-tokens.mjs \
  --dry-run --transcript /pfad/zur/session.jsonl --event Stop

# 3) Connectivity-Test gegen die konfigurierte URL
TOKEN_REPORTER_URL=https://meine-api.example.com/usage \
  node ~/.claude/token-reporter/plugin/scripts/report-tokens.mjs --ping
```

In einer Sitzung mit installiertem Plugin: `/token-reporter:status` zeigt die
Konfiguration und sendet einen Ping.

---

## Sicherheit / Datenschutz

- Es werden **nur Metadaten** gesendet (Token-Zahlen, Projektname/-pfad, Git-Remote/Branch,
  Modellnamen, Session-ID) – **kein** Inhalt des Transcripts und keine Nachrichten.
- Der Reporter fängt alle Fehler ab und endet immer mit Exit-Code 0; er blockiert oder
  unterbricht Claude Code niemals.
- Möchtest du den Git-Remote nicht melden, setze `TOKEN_REPORTER_PROJECT` und entferne ggf.
  das Feld serverseitig.
