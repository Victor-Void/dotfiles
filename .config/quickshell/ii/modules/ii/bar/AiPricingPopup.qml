import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    required property string provider
    readonly property var cells: root.provider === "deepseek" ? PeakHours.deepseekPriceCells : PeakHours.anthropicPriceCells

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        StyledPopupHeaderRow {
            icon: "payments"
            label: root.provider === "deepseek"
                ? Translation.tr("DeepSeek API — USD / 1M tokens")
                : Translation.tr("Anthropic API — USD / 1M tokens")
        }

        GridLayout {
            columns: 4
            columnSpacing: 14
            rowSpacing: 2

            Repeater {
                model: root.cells
                delegate: StyledText {
                    required property var modelData

                    Layout.row: modelData.row
                    Layout.column: modelData.col
                    Layout.alignment: modelData.col === 0 ? Qt.AlignLeft : Qt.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                    font.weight: modelData.header ? Font.DemiBold : Font.Normal
                    text: modelData.text
                }
            }
        }
    }
}
