import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleModel {
    id: root
    name: Translation.tr("Tailscale")
    toggled: false
    icon: "vpn_lock"

    mainAction: () => {
        if (toggled) {
            root.toggled = false
            Quickshell.execDetached(["tailscale", "down"])
        } else {
            root.toggled = true
            Quickshell.execDetached(["tailscale", "up"])
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
                    root.available = true
                }
                root.toggled = tsStatusCollector.text.includes("\"BackendState\": \"Running\"")
            }
        }
    }

    tooltipText: Translation.tr("Tailscale VPN")
}
