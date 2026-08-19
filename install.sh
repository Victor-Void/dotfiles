#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
DEST="$HOME/.config"

LINK_MODE=false
SKIP_DEPS=false

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'
info()  { echo -e "${GREEN}[*]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --link       Symlink quickshell/ (live-edit the shell config from the repo).
               hypr/ and illogical-impulse/ are still materialized so paths
               can be resolved.
  --no-deps    Skip dependency checks/installation
  -h, --help   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --link)    LINK_MODE=true; shift ;;
        --no-deps) SKIP_DEPS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- deps ----
if [[ "$SKIP_DEPS" == false ]]; then
    info "Checking dependencies..."
    MISSING=""
    for bin in hyprland qs; do
        command -v "$bin" >/dev/null 2>&1 || MISSING="$MISSING $bin"
    done

    if [[ -n "$MISSING" ]]; then
        warn "Missing binaries:$MISSING"
        if command -v pacman >/dev/null 2>&1; then
            warn "Arch: quickshell is in the AUR (e.g. 'yay -S quickshell')."
            warn "Install quickshell first, then re-run ./install.sh --no-deps to continue."
        else
            warn "Quickshell must be installed manually on your distribution."
            warn "See https://quickshell.outfoxxed.me/ for build/install instructions."
        fi
        if [[ "$MISSING" == *hyprland* ]]; then
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --needed hyprland
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y hyprland
            elif command -v apt >/dev/null 2>&1; then
                sudo apt install -y hyprland
            fi
        fi
        info "Continuing with config install; re-run after installing Quickshell if needed."
    else
        info "Hyprland + Quickshell found."
    fi
fi

# ---------------------------------------------------------- materialize ----
# Resolve $HOME placeholders into a staging copy so the repo stays portable.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -r "$CONFIG_SRC" "$STAGE/.config"
sed -i "s|\$HOME|$HOME|g" "$STAGE/.config/illogical-impulse/config.json"
sed -i "s|\$HOME|$HOME|g" "$STAGE/.config/hypr/hyprlock/colors.conf"

# ----------------------------------------------------------------- copy ----
info "Installing configs to $DEST"
mkdir -p "$DEST"

if [[ "$LINK_MODE" == true ]]; then
    if [[ -e "$DEST/quickshell" ]]; then
        warn "$DEST/quickshell already exists, skipping symlink."
    else
        ln -sfn "$CONFIG_SRC/quickshell" "$DEST/quickshell"
    fi
    if [[ -e "$DEST/hypr" ]]; then
        warn "$DEST/hypr already exists, skipping."
    else
        cp -r "$STAGE/.config/hypr" "$DEST/"
    fi
else
    if [[ -e "$DEST/quickshell" ]]; then
        warn "$DEST/quickshell already exists, skipping."
    else
        cp -r "$STAGE/.config/quickshell" "$DEST/"
    fi
    if [[ -e "$DEST/hypr" ]]; then
        warn "$DEST/hypr already exists, skipping."
    else
        cp -r "$STAGE/.config/hypr" "$DEST/"
    fi
fi

if [[ -e "$DEST/illogical-impulse" ]]; then
    warn "$DEST/illogical-impulse already exists, skipping."
else
    cp -r "$STAGE/.config/illogical-impulse" "$DEST/"
fi

info "Configs installed."

# ------------------------------------------------------------ post notes ----
cat <<EOF

${GREEN}Done!${NC} A few notes:

  1. Wallpapers: the config points at:
       $HOME/Pictures/Wallpapers/wallpaper.jpg
     Drop an image there (or change 'wallpaperPath' in
     $DEST/illogical-impulse/config.json). Set the same path in
     $DEST/hypr/hyprlock/colors.conf for the lock screen.

  2. Launch the shell from Hyprland:
       qs -c ii
     Bind it in hyprland/keybinds.lua if it is not already.

  3. Edit keybinds/startup in:
       $DEST/hypr/custom/   (user overrides)
     The main config lives in $DEST/hypr/hyprland/.

  4. Re-login after installing to apply env vars and execs.

EOF