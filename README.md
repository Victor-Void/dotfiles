# ii · Quickshell + Hyprland dotfiles

A fully configured **Hyprland** desktop with the **ii** Quickshell shell — a
highly customizable widget/panel suite (bar, launcher, clipboards, media,
wallpapers, notes, widgets, session controls, and more), powered by
[end4/dots-hyprland](https://github.com/end4/dots-hyprland).

This is a stripped-down, system-agnostic mirror of the author's daily driver:
no hardware-specific startup items, no personal paths, portable by default.

## Features

- Modern bar with workspaces, clock, tray, and a dedicated **opencode** launcher button
- App launcher, clipboard history, emoji picker, Google-Lens-style region search
- Notes widget, quick notes on `SUPER + Comma`
- Media controls, on-screen keyboard, wallpaper selector, session menu
- Waffle panel family (alternative UI) with its own action center
- Peak-hours monitor service (DeepSeek/Anthropic rate-limit aware alerts)
- Hyprlock + Hypridle screen locking, `custom/` overrides for your own keybinds
- English-only, light/dark aware

## Requirements

- [Hyprland](https://hyprland.org) (Wayland compositor)
- [Quickshell](https://quickshell.outfoxxed.me/) — on Arch: `quickshell` (AUR)
- Qt6 modules that Quickshell links against (installed as Quickshell deps)
- Fonts: Material Symbols, a Nerd Font, and the fonts referenced in `hypr/hyprland/colors.lua`
- Optional tools used by keybinds: `fuzzel`, `grim`, `slurp`, `hyprpicker`,
  `wl-clipboard`, `cliphist`, `wpctl`/`brightnessctl`, `playerctl`, `ffplay`

## Install

```bash
git clone https://github.com/Victor-Void/dotfiles.git
cd dotfiles
./install.sh            # copy mode (recommended)
./install.sh --link     # symlink quickshell/ for live-edit + git tracking
./install.sh --no-deps  # skip dependency checks
```

The script:

1. Installs dependencies (Arch): Hyprland, Quickshell, Qt deps, capture/OS
   tools, fonts — using `yay`/`paru` if present (installs `paru` otherwise).
   Non-Arch distros get the package list printed instead.
2. Copies the configs into `~/.config` (hypr, quickshell/ii, illogical-impulse).
3. Resolves `$HOME` placeholders so paths work on your machine.
4. Prints post-install notes (wallpaper path, launching `qs -c ii`).

> The config points at `~/Pictures/Wallpapers/wallpaper.jpg` for the desktop and
> lock-screen background. Drop an image there or change `wallpaperPath` in
> `~/.config/illogical-impulse/config.json`.

Then log out and back in, and make sure `qs -c ii` is started from your Hyprland
config (bind it in `hyprland/keybinds.lua` if it isn't already).

## Layout

```
.config/
├── hypr/                       # Hyprland config (Lua)
│   ├── hyprland.lua            # sources everything below
│   ├── custom/                 # <-- YOUR overrides (keybinds, execs, env, rules)
│   ├── hyprland/               # defaults: keybinds, execs, general, env, rules, colors
│   │   ├── scripts/            # helper scripts (launchers, snip-to-search, ...)
│   │   └── shellOverrides/     # per-family shell tweaks
│   ├── hypridle.conf
│   ├── hyprlock.conf
│   └── hyprlock/               # lock screen (colors.conf is matugen-generated)
├── quickshell/
│   └── ii/                     # the shell (run with: qs -c ii)
│       ├── shell.qml
│       ├── modules/            # bar, panels, overlays, widgets
│       ├── services/           # background services
│       ├── scripts/            # shell helper scripts
│       └── translations/
└── illogical-impulse/
    └── config.json             # shell settings (per-machine, gets $HOME resolved)
```

## Keybinds (defaults)

### Shell
| Key | Action |
| --- | --- |
| `SUPER + Space`/`SUPER_L`/`SUPER_R` | Search / launcher |
| `SUPER + Tab` | Workspace overview |
| `SUPER + V` | Clipboard history |
| `SUPER + .` | Emoji picker |
| `SUPER + N` | Right sidebar |
| `SUPER + /` | Cheatsheet |
| `SUPER + K` | On-screen keyboard |
| `SUPER + M` | Media controls |
| `SUPER + G` | Widget overlay |
| `SUPER + ,` | Notes widget |
| `SUPER + J` | Toggle bar |
| `CTRL + ALT + Del` | Session menu |

### Screen / capture
| Key | Action |
| --- | --- |
| `Print` | Full screenshot → clipboard |
| `SUPER + SHIFT + S` | Region screenshot |
| `SUPER + SHIFT + A` | Region → search (Lens-style) |
| `SUPER + SHIFT + X` | Region → OCR |
| `SUPER + SHIFT + R` / `SUPER + ALT + R` | Region record |
| `CTRL + ALT + R` | Fullscreen record |

### Window / workspace
| Key | Action |
| --- | --- |
| `SUPER + arrows` | Move focus |
| `SUPER + SHIFT + arrows` | Move window |
| `SUPER + Q` | Close window |
| `SUPER + ALT + Space` | Float/tile |
| `SUPER + ALT + F` | Maximize |
| `SUPER + F` | Fullscreen |
| `SUPER + P` | Pin |
| `SUPER + 1..0` | Switch workspace |

### Media / misc
| Key | Action |
| --- | --- |
| `XF86*` | Volume / brightness / media keys |
| `SUPER + SHIFT + B` / `P` | Prev / play-pause |
| `SUPER + SHIFT + M` | Mute |
| `SUPER + =` / `-` | Zoom in / out |

### Custom (`hypr/custom/keybinds.lua`)
| Key | Action |
| --- | --- |
| `SUPER + D` | Discord scratchpad |
| `SUPER + ALT + F` | Maximize (re-mapped) |
| `CTRL+SUPER+ALT+/` | Edit user keybinds |

Edit your own bindings in `hypr/custom/keybinds.lua` — it is loaded last and can
`unbind` defaults. Startup commands go in `hypr/custom/execs.lua`.

## Customization

- **Keybinds / startup / env / rules**: `hypr/custom/`
- **Shell appearance & widgets**: `quickshell/ii/` — with `--link` install, edits
  are tracked in git.
- **Wallpaper**: `~/Pictures/Wallpapers/wallpaper.jpg` or `qs -p .../settings.qml`
  → Appearance.

## Credits

- [end4/dots-hyprland](https://github.com/end4/dots-hyprland) — the original shell
  this is based on
- [Quickshell](https://quickshell.outfoxxed.me/) — the shell framework
- [Hyprland](https://hyprland.org) — the compositor