# Rules

- never ever commit or push unless you're told to.
- never ever add Co-Authored by to commit messages
- instead of printing multiline cli commands to the user create a simple script in /tmp and just tell the user the script name instead of the multiline ouput because copy pasting multiline statements is not working well
- never ever start testing with firefox or chrome urself, only when you're asked to.

# Tailwind CSS

- Niemals arbitrary values (`z-[2]`, `mt-[13px]`, `gap-[7]`, `p-[4]`) verwenden, wenn die native Scale dasselbe ausdrücken kann. Tailwind v4 erlaubt nackte Zahlen für viele Utilities (Spacing, z-index, grid, etc.) — bevorzuge `z-2`, `mt-13`, `gap-7`.
- Bracket-Notation `[...]` nur dann, wenn der Wert wirklich nicht durch die Scale/Theme-Tokens ausdrückbar ist (z. B. ungewöhnliche Einheiten, CSS-Variablen, calc-Ausdrücke).
- Bei bestehendem Code: wenn du eine Datei editierst und siehst, dass eine Klasse als Bracket-Notation steht, obwohl die Scale reicht, korrigiere sie im Zuge des Edits mit.
