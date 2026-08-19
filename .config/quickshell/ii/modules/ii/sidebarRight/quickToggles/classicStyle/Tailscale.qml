import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Io
import Quickshell

QuickToggleButton {
    id: root
    toggled: false
    visible: false
    buttonIcon: root.toggled ? "vpn_lock" : "vpn_key_off"

    onClicked: {
        if (toggled) {
            root.toggled = false
            Quickshell.execDetached(["tailscale", "down"])
        } else {
            root.toggled = true
            Quickshell.execDetached(["tailscale", "up"])
        }
    }

    Process {
        id: upProc
        command: ["tailscale", "up"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Tailscale"),
                    Translation.tr("Connection failed. Please inspect manually with the <tt>tailscale</tt> command")
                    , "-a", "Shell"
                ])
            }
        }
    }

    Process {
        id: fetchActiveState
        running: true
        command: ["bash", "-c", "tailscale status --json"]
        stdout: StdioCollector {
            id: tsStatusCollector
            onStreamFinished: {
                if (tsStatusCollector.text.length > 0) {
                    root.visible = true
                }
                if (tsStatusCollector.text.includes("\"BackendState\": \"Running\"")) {
                    root.toggled = true
                } else {
                    root.toggled = false
                }
            }
        }
    }

    StyledToolTip {
        text: Translation.tr("Tailscale VPN")
    }
}
