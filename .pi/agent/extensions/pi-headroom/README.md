# pi-headroom

Pi-Extension, die [Headroom](https://headroom.ai) (Context-Optimierungs-Proxy)
automatisch mit Pi startet und konfigurierte Provider durch den Proxy routet.

## Was es tut

- **Auto-Start:** Beim Start einer Pi-Instanz wird geprüft, ob bereits ein
  `headroom proxy` läuft (`GET /health`). Wenn nicht, wird einer gestartet
  (Spawn-Lock gegen Race-Conditions zwischen gleichzeitig startenden
  Pi-Instanzen).
- **Geteilte Instanz:** Alle Pi-Instanzen sprechen mit demselben Proxy. Eine
  Instanz startet, die anderen adoptieren.
- **Prompt-Kompression:** Die baseUrl der gerouteten Provider wird auf den
  Proxy umgebogen, sodass alle Prompts/Context durch Headroom fließen und
  dort komprimiert werden. Headroom leitet an den echten Upstream
  (z. B. Ollama) weiter.
- **Auto-Shutdown:** Jede Pi-Instanz registriert sich mit ihrer PID als
  Client. Beendet sich die **letzte** Instanz, wird der Proxy beendet. Ein
  extern (von Hand) gestarteter Proxy ohne PID-File wird nicht angefasst.
- Abgestürzte Pi-Prozesse hinterlassen stale Client-Files, die beim nächsten
  Start bzw. vor Shutdown-Entscheidungen automatisch aufgeräumt werden.

## Installation

```bash
pi install /home/max/Projects/pi-headroom
```

## Konfiguration

`~/.pi/agent/extensions/pi-headroom.json` (alles optional):

```json
{
  "enabled": true,
  "host": "127.0.0.1",
  "port": 8787,
  "mode": "cache",
  "providers": [],
  "headroomCommand": "headroom",
  "startupTimeoutMs": 20000
}
```

- `providers`: Pi-Provider-Namen, die geroutet werden. Leer = Auto-Erkennung
  (alle Provider aus `models.json` mit `api: "openai-completions"` und
  loopback-`baseUrl`, z. B. ollama).
- `mode`: Headroom-Optimierungsmodus, `cache` (prefix-cache-freundlich) oder
  `token` (aggressive Kompression).
- Der Upstream für Headroom wird aus der `baseUrl` des ersten gerouteten
  Providers in `models.json` übernommen.

## Befehle

- `/headroom` — Status anzeigen (Proxy, PID, Modus, geroutete Provider,
  Anzahl laufender Pi-Clients)
- `/headroom stop` — Proxy stoppen (verweigert, wenn noch andere Pi-Instanzen
  ihn nutzen)
- `/headroom restart` — Proxy neu starten

## Debugging

```bash
PI_HEADROOM_DEBUG=1 pi   # schreibt nach /tmp/pi-headroom-debug.log
```

Proxy-Stderr landet in `~/.pi/agent/headroom/proxy.log`, Headrooms eigene
Logs in `~/.headroom/logs/`.