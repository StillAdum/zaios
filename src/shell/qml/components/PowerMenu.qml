/*
 * PowerMenu.qml — Power menu overlay (full screen dim + 3 big buttons).
 *
 * Shows: Power Off, Restart, Suspend, Cancel
 * Triggered by the power key on the remote or Ctrl+Alt+Del.
 *
 * Each button is a big card with icon + label, D-pad navigable.
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell
import "../styles"

Item {
    id: powerRoot

    // Dim background
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)

        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
    }

    // Centered card
    GlassCard {
        anchors.centerIn: parent
        width: 720
        height: 360
        radius: Theme.radiusXL
        glow: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceXL
            spacing: Theme.spaceL

            Text {
                text: "Power"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeXL
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceM

                PowerButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "⏻"
                    label: "Power Off"
                    accentColor: Theme.error
                    focus: true
                    onClicked: Power.powerOff()
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "↻"
                    label: "Restart"
                    accentColor: Theme.warning
                    onClicked: Power.reboot()
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "🌙"
                    label: "Suspend"
                    accentColor: Theme.accentSoft
                    onClicked: Power.suspend()
                }
                PowerButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "✕"
                    label: "Cancel"
                    accentColor: Theme.textSecondary
                    onClicked: root.powerMenuVisible = false
                }
            }
        }
    }

    // Close on background click
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.powerMenuVisible = false
    }

    component PowerButton: FocusButton {
        property string iconText: ""
        property color  accentColor: Theme.accent
        cornerRadius: Theme.radiusL
        bgColor: Qt.rgba(0, 0, 0, 0.3)
        bgColorFocused: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
        scaleOnFocus: 1.05

        contentItem: Column {
            anchors.centerIn: parent
            spacing: Theme.spaceS

            Text {
                text: parent.parent.iconTextText
                font.pixelSize: 48
                color: parent.parent.activeFocus ? parent.parent.accentColor : Theme.textPrimary
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            Text {
                text: parent.parent.label
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.pixelSize: Theme.fontSizeM
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
