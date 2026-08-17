# ══════════════════════════════════════════════════════════════════════
# zsh core setup  (ehemals oh-my-zsh — jetzt nativ, schlank & schnell)
# ══════════════════════════════════════════════════════════════════════
# Die Konfiguration ist in modulare Files in ~/dotfiles/shell/ aufgespalten.
# Sie werden hier in lexikalischer Reihenfolge (00-, 10-, …) gesourced. Die
# Nummerierung gibt die Lade-Reihenfolge vor — sie ist ladungsrelevant:
#   compinit (00) → fzf-tab (70) → zsh-syntax-highlighting (ganz zuletzt).
# Neues File: einfach NN-name.zsh in ~/dotfiles/shell/ anlegen, es wird
# automatisch mitgeladen. Für einen echten Reload: `exec zsh`.
for _f in "$HOME/dotfiles/shell"/[0-9][0-9]-*.zsh(N); do
  source "$_f"
done
unset _f
