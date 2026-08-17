# ══════════════════════════════════════════════════════════════════════
# 10-env.zsh — Environment-Variablen & Session-Erkennung.
# Vor 20-path laden, damit $ANDROID_HOME / $PROJECTS_DIR etc. gesetzt sind,
# bevor die PATH-Appends in 20-path darauf zugreifen.
# ══════════════════════════════════════════════════════════════════════

. "$HOME/.local/share/../bin/env"

# --- PROJECTS_DIR: wo die Code-Projekte liegen -----------------------
# Single Source of Truth (siehe ~/dotfiles/projects-dir.sh). Muss vor
# allem stehen, was Projektpfade braucht (vault, tmux-sessionizer).
source "$HOME/dotfiles/projects-dir.sh"

export ANDROID_HOME="$HOME/Android/Sdk/"

# --- Locale ----------------------------------------------------------
# Bewusst leer: die System-Locale kommt aus /etc/locale.conf (en_US.UTF-8) und
# gilt damit fuer Terminal- UND GUI-Apps gleich. Frueher hat dieser Block sie
# hier auf de_DE ueberschrieben — Ergebnis waren deutsche CLI-Tools und
# englische GUI-Apps. Das Tastaturlayout haengt NICHT daran, das steht in
# /etc/vconsole.conf und in kb_layout (hypr/hyprland.lua).

# --- NVIDIA / GPU ---
export GBM_BACKEND="nvidia-drm"
export __GLX_VENDOR_LIBRARY_NAME="nvidia"
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=1
export WLR_NO_HARDWARE_CURSORS=1
export LIBVA_DRIVER_NAME="nvidia"
export __VK_LAYER_NV_optimus="NVIDIA_only"

# --- Wayland / Session ---
export XDG_SESSION_TYPE="wayland"
export XDG_DATA_DIRS="/usr/share:usr/local/share:$HOME/.local/share"

# Compositor-Erkennung: Sway setzt SWAYSOCK, Hyprland setzt HYPRLAND_INSTANCE_SIGNATURE
if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
  export XDG_CURRENT_DESKTOP="Hyprland"
  export HYPRCURSOR_SIZE=24
elif [[ -n "$SWAYSOCK" ]]; then
  export XDG_CURRENT_DESKTOP="sway"
fi

# --- Qt / Cursor ---
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME="qt5ct"
export QT_STYLE_OVERRIDE="kvantum"
export XCURSOR_SIZE=24

export PNPM_HOME="$HOME/.local/share/pnpm"

export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export INSTALL4J_JAVA_HOME="$JAVA_HOME"

# --- Go (env + bin zusammen, damit der Guard nur einmal steht) -------
if [[ -d "$HOME/go" ]]; then
    export GOPATH="$HOME/go"
    export GOPRIVATE=github.com/maxischmaxi/*
    export GOROOT="/usr/lib/go"
    # Go-Cache auf die grosse Platte, wenn es sie gibt — sonst Go-Default
    # (~/.cache/go-build). Ohne Guard wuerde Go auf einer Maschine ohne
    # /stuff bei jedem Build auf ein nicht existierendes Verzeichnis zeigen.
    [[ -d /stuff/cache ]] && export GOCACHE="/stuff/cache/go-build"
    export PATH="$PATH:$HOME/go/bin"
fi

export ENV=development
export EDITOR="nvim"

export DYLD_LIBRARY_PATH="/usr/local/lib:$DYLD_LIBRARY_PATH"
