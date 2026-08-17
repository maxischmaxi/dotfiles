# Dotfiles (~/.config)

## Symlinks

Einige Configs liegen hier, werden aber an anderer Stelle erwartet und müssen nach dem Klonen manuell verlinkt werden.

### zshrc

```bash
ln -sf /home/max/.config/zshrc.zsh /home/max/.zshrc
```

Die zsh-Konfiguration liegt in `~/.config/zshrc.zsh`, wird aber von zsh unter `~/.zshrc` erwartet.

### SDDM

```bash
sudo ln -sf /home/max/.config/sddm/sddm.conf /etc/sddm.conf.d/99-numlock.conf
```

SDDM ist ein System-Service und liest nur aus `/etc/sddm.conf.d/`. Der Symlink macht die hier getrackten Einstellungen (NumLock on) für SDDM sichtbar.
