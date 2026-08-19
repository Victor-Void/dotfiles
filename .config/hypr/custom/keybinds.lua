hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )


hl.unbind("SUPER + ALT + F")

hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),

    { description = "Window: Maximize" })

hl.bind("SUPER + D", hl.dsp.exec_cmd(

    "hyprctl dispatch togglespecialworkspace discord; pgrep discord || discord"

), { description = "App: Discord (scratchpad)" })


