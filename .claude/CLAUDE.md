# Rules

- never ever commit or push unless you're told to.
- never ever add Co-Authored by to commit messages
- instead of printing multiline cli commands to the user create a simple script in /tmp and just tell the user the script name instead of the multiline ouput because copy pasting multiline statements is not working well
- never ever start testing with firefox or chrome urself, only when you're asked to.
- never ever run git stash, assume we are running multiple sessions at once therefore there might be changes that would be affected as well
- never ever write german comments in files, always english. dont write over expressive comments, keep them short and simple as far as posslbe
- when you move or rename files inside a git repository always use git mv so git tracks it correctly
- always answer in lowercase in any language except if you're told otherwise

# general info

- we're using arch/hyprland keep in mind that if you control windows like chrome etc that we have a tiling window manager and windows might be very small due to that

# Tailwind CSS

- Niemals arbitrary values (`z-[2]`, `mt-[13px]`, `gap-[7]`, `p-[4]`) verwenden, wenn die native Scale dasselbe ausdrücken kann. Tailwind v4 erlaubt nackte Zahlen für viele Utilities (Spacing, z-index, grid, etc.) — bevorzuge `z-2`, `mt-13`, `gap-7`.
- Bracket-Notation `[...]` nur dann, wenn der Wert wirklich nicht durch die Scale/Theme-Tokens ausdrückbar ist (z. B. ungewöhnliche Einheiten, CSS-Variablen, calc-Ausdrücke).
- Bei bestehendem Code: wenn du eine Datei editierst und siehst, dass eine Klasse als Bracket-Notation steht, obwohl die Scale reicht, korrigiere sie im Zuge des Edits mit.
