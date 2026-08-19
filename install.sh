#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
DEST="$HOME/.config"

LINK_MODE=false
SKIP_DEPS=false
ASSUME_YES=false

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
  --no-deps    Skip dependency installation
  -y, --yes    Assume yes to package prompts (no confirmation)
  -h, --help   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --link)    LINK_MODE=true; shift ;;
        --no-deps) SKIP_DEPS=true; shift ;;
        -y|--yes)  ASSUME_YES=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- deps ----
# Packages needed by the shell + hyprland config.
ARCH_ESSENTIAL="hyprland hypridle hyprlock quickshell kitty fuzzel grim slurp hyprpicker wl-clipboard cliphist satty swappy ffmpeg wireplumber brightnessctl playerctl libpulse ydotool wtype mako imagemagick matugen gnome-keyring ttf-jetbrains-mono-nerd noto-fonts ttf-material-symbols-variable"
ARCH_OPTIONAL="mpvpaper cava easyeffects ttf-google-sans-hinted"
# quickshell itself is not in the Arch repos; installed from the AUR below.

install_arch() {
    local pkgs="quickshell $ARCH_ESSENTIAL $ARCH_OPTIONAL"
    if [[ "$ASSUME_YES" == true ]]; then
        local yes="--noconfirm"
    else
        info "About to install:"
        echo "  $pkgs"
        read -r -p "Proceed? [y/N] " ans || true
        [[ "$ans" =~ ^[yY]$ ]] || { warn "Dependency install skipped."; return 0; }
    fi

    local helper=""
    if command -v paru >/dev/null 2>&1; then helper=paru
    elif command -v yay  >/dev/null 2>&1; then helper=yay
    fi

    if [[ -z "$helper" ]]; then
        info "No AUR helper found; installing paru..."
        sudo pacman -S --needed --noconfirm git base-devel
        local tmp
        tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/paru.git "$tmp/paru"
        (cd "$tmp/paru" && makepkg -si --noconfirm)
        helper=paru
    fi

    info "Installing packages with $helper (repo + AUR)..."
    "$helper" -S --needed $yes $pkgs
}

install_deps() {
    info "Checking dependencies..."
    if command -v pacman >/dev/null 2>&1; then
        install_arch
    else
        warn "Auto-install is currently supported for Arch-based systems."
        warn "Recommended packages:"
        echo "  hyprland hypridle hyprlock quickshell kitty fuzzel grim slurp"
        echo "  hyprpicker wl-clipboard cliphist satty swappy ffmpeg wireplumber"
        echo "  brightnessctl playerctl ydotool wtype mako imagemagick matugen"
        echo "  mpvpaper cava fonts (Material Symbols, a Nerd Font)"
        warn "Quickshell is not packaged on most non-Arch distros; build it from"
        warn "source (see https://quickshell.outfoxxed.me/). Continuing anyway."
    fi
}

if [[ "$SKIP_DEPS" == false ]]; then
    install_deps
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

  4. Optional: image-processing scripts use python deps
     (pip install --user materialyoucolor opencv-python) and video wallpapers
     need mpvpaper + ffmpeg.

  5. Re-login after installing to apply env vars and execs.

EOF