import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property string formattedDate: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM dd, yyyy")
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    property string todosSection: getUpcomingTodos()

    function getUpcomingTodos() {
        const unfinishedTodos = Todo.list.filter(function (item) {
            return !item.done;
        });
        if (unfinishedTodos.length === 0) {
            return Translation.tr("No pending tasks");
        }

        // Limit to first 5 todos to keep popup manageable
        const limitedTodos = unfinishedTodos.slice(0, 5);
        let todoText = limitedTodos.map(function (item, index) {
            return `  ${index + 1}. ${item.content}`;
        }).join('\n');

        if (unfinishedTodos.length > 5) {
            todoText += `\n  ${Translation.tr("... and %1 more").arg(unfinishedTodos.length - 5)}`;
        }

        return todoText;
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

        StyledPopupHeaderRow {
            icon: "calendar_month"
            label: root.formattedDate
        }

        RowLayout {
            spacing: 4

            MaterialSymbol {
                text: "timelapse"
                color: Appearance.colors.colOnSurfaceVariant
                iconSize: Appearance.font.pixelSize.large
            }

            StyledText {
                text: Translation.tr("System uptime:")
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                text: root.formattedUptime
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        // AI API peak hours
        ColumnLayout {
            spacing: 4

            StyledPopupHeaderRow {
                icon: "bolt"
                label: Translation.tr("AI API peak hours:")
            }

            ColumnLayout {
                spacing: 2

                RowLayout {
                    spacing: 6

                    CustomIcon {
                        source: "deepseek-symbolic"
                        colorize: true
                        color: Appearance.colors.colOnSurfaceVariant
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                    }

                    StyledText {
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colOnSurfaceVariant
                        text: "DeepSeek API:  " + PeakHours.deepseekLine
                    }
                }

                StyledText {
                    Layout.leftMargin: 20
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurfaceVariant
                    text: "(" + PeakHours.deepseekStatus + ")"
                }
            }

            ColumnLayout {
                spacing: 2

                RowLayout {
                    spacing: 6

                    CustomIcon {
                        source: "anthropic-symbolic"
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                    }

                    StyledText {
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colOnSurfaceVariant
                        text: "Anthropic Subscription:  " + PeakHours.anthropicLine
                    }
                }

                StyledText {
                    Layout.leftMargin: 20
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurfaceVariant
                    text: "(" + PeakHours.anthropicStatus + ")"
                }
            }
        }

        // Tasks
        Column {
            spacing: 0
            Layout.fillWidth: true

            StyledPopupValueRow {
                icon: "checklist"
                label: Translation.tr("To Do:")
                value: ""
            }

            StyledText {
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSurfaceVariant
                text: root.todosSection
            }
        }
    }
}
