#!/usr/bin/env bash
# Update Neovim from the local source checkout at ~/neovim.
# Workflow: pull -> incremental build (Ninja) -> install to /usr/local.
set -euo pipefail

NEOVIM_DIR="${NEOVIM_DIR:-$HOME/neovim}"
BUILD_DIR="$NEOVIM_DIR/build"

if [[ ! -d "$NEOVIM_DIR/.git" ]]; then
    echo "✗ $NEOVIM_DIR is not a git checkout" >&2
    exit 1
fi
if [[ ! -f "$BUILD_DIR/build.ninja" ]]; then
    echo "✗ $BUILD_DIR has no build.ninja — run 'cmake --preset default' once first" >&2
    exit 1
fi

cd "$NEOVIM_DIR"

# Fetch + fast-forward the current branch (master).
echo "→ git fetch origin"
git fetch --quiet --tags origin
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "→ git pull (branch: $CURRENT_BRANCH)"
git pull --ff-only

if [[ "$(git rev-parse @)" == "$(git rev-parse @{u})" ]]; then
    echo "  (already up to date)"
fi

# Incremental build. Ninja re-runs CMake automatically when CMakeLists.txt changed.
# Pass --parallel to be explicit; Ninja defaults to nproc anyway.
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)"
echo "→ cmake --build build (jobs: $JOBS)"
cmake --build "$BUILD_DIR" --parallel "$JOBS"

# Install to /usr/local. The binary there is root-owned, so sudo is required.
if [[ -w /usr/local/bin/nvim || ! -e /usr/local/bin/nvim ]]; then
    INSTALL_CMD=()
else
    INSTALL_CMD=(sudo)
fi
echo "→ ${INSTALL_CMD[*]:-}cmake --install build"
"${INSTALL_CMD[@]}" cmake --install "$BUILD_DIR" --quiet 2>/dev/null || \
    "${INSTALL_CMD[@]}" cmake --install "$BUILD_DIR"

# Show the freshly installed version.
NEW_VER="$(/usr/local/bin/nvim --version | head -1)"
echo
echo "✓ done — $NEW_VER"