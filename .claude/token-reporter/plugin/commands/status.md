---
description: Konfiguration des Project Token Reporter anzeigen und einen Test-Ping an die REST-API senden
---

Der Nutzer moechte den Status des "Project Token Reporter"-Plugins pruefen. Gehe knapp vor:

1. Zeige, welche Konfiguration gesetzt ist:
   `printenv | grep -E '^TOKEN_REPORTER_' || echo 'keine TOKEN_REPORTER_* Variablen gesetzt'`
   Maskiere dabei den Wert von `TOKEN_REPORTER_TOKEN` (nur "gesetzt"/"nicht gesetzt" zeigen).

2. Wenn `TOKEN_REPORTER_URL` gesetzt ist, sende einen Test-Request:
   `node "${CLAUDE_PLUGIN_ROOT}/scripts/report-tokens.mjs" --ping`
   und berichte das Ergebnis (HTTP-Status bzw. Fehler).

3. Fasse zusammen: Ist ein Endpoint konfiguriert? Was war das Ping-Ergebnis? Falls `TOKEN_REPORTER_URL`
   fehlt, weise kurz darauf hin, wie man sie setzt (siehe README des Plugins) und dass das Plugin
   ohne URL ein No-Op ist.

Halte die Antwort kurz.
