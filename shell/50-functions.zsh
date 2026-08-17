# ══════════════════════════════════════════════════════════════════════
# 50-functions.zsh — eigene Shell-Funktionen + chpwd-Hooks.
# chpwd-Hooks (osc7, node_modules/.bin) müssen VOR zoxide (70) registriert
# werden, damit zoxide sich sauber obendrauf stackt.
# ══════════════════════════════════════════════════════════════════════

# OSC 7 — reports the current directory to the terminal.
# Ghostty uses it for "new tab/split in the same directory", and tmux keeps
# pane_current_path in sync from it (used by `bind c` / `bind v`).
_osc7_cwd() {
  printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}"
}
add-zsh-hook chpwd _osc7_cwd
_osc7_cwd  # Report on shell startup

# Chronos — lazydocker auf QA/Prod VMs via SSH-forwarded docker.sock.
# (DOCKER_HOST=ssh:// hängt bei lazydocker — Unix-Socket-Forward ist stabil.)
_chronos_lazydocker() {
  local host="$1" sock="$2"
  rm -f "$sock"
  ssh -fnNT -o ExitOnForwardFailure=yes -L "$sock:/var/run/docker.sock" "root@$host" || {
    echo "SSH-Forward nach $host fehlgeschlagen" >&2
    return 1
  }
  DOCKER_HOST="unix://$sock" lazydocker
  pkill -f "ssh.*$sock" 2>/dev/null
  rm -f "$sock"
}
chronos-qa()   { _chronos_lazydocker 116.203.119.218 /tmp/docker-qa.sock }
chronos-prod() { _chronos_lazydocker 116.203.57.55  /tmp/docker-prod.sock }

# killapp — laufende Apps (nach RAM gruppiert) interaktiv beenden. Tray-Ersatz
# ohne Waybar. TAB = mehrere wählen · ENTER = beenden · ESC = abbrechen.
# Beendet nur den HAUPTprozess jeder App (der, dessen Parent NICHT zur App
# gehört) und lässt ihn seine Kindprozesse selbst sauber schließen. Sonst hängen
# sich manche Electron-Apps (z. B. teams-for-linux) auf, wenn man alle Prozesse
# gleichzeitig killt — der Hauptprozess wartet dann auf schon tote Kinder.
killapp() {
  local sel
  sel=$(ps -eo rss=,comm= \
    | awk '{rss=$1; $1=""; sub(/^ +/,""); c=$0
            if (c ~ /^(Hyprland|fzf|awk|sort|ps|sed|cut|xargs)$/) next
            a[c]+=rss; n[c]++}
           END {for (k in a) printf "%d\t%s\t%d\n", a[k], k, n[k]}' \
    | sort -rn \
    | awk -F'\t' '{printf "%-18s\t%6d MB\t%d Prozess(e)\n", $2, $1/1024, $3}' \
    | fzf --multi --delimiter='\t' --with-nth=1,2,3 \
          --header='TAB=mehrere · ENTER=beenden · ESC=abbrechen' \
    | cut -f1 | sed 's/[[:space:]]*$//')
  [[ -z "$sel" ]] && return
  local app pid ppid pcomm roots
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    roots=""
    # Root-Prozesse sammeln (Parent gehört nicht zur App), solange noch alle leben
    for pid in ${(f)"$(pgrep -x -- "$app")"}; do
      ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
      [[ -z "$ppid" ]] && continue
      pcomm=$(ps -o comm= -p "$ppid" 2>/dev/null)
      [[ "$pcomm" != "$app" ]] && roots+="$pid "
    done
    if [[ -n "$roots" ]]; then
      echo "killapp: SIGTERM → $app (Hauptprozess ${roots% })"
      kill -TERM ${=roots} 2>/dev/null
    else
      echo "killapp: $app nicht (mehr) gefunden"
    fi
  done <<< "$sel"
}
