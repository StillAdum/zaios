/*
 * BatteryBadge.qml - Battery status indicator.
 *
 * Reads /sys/class/power_supply/BAT-something/capacity and status.
 * Most TVs don't have a battery, so this hides itself if no battery found.
 */
import QtQuick
import ZAIos.Shell
import "../styles"

Item {
    width: 56
    height: 36
    visible: hasBattery

    property bool hasBattery: false
    property int  capacity: 0
    property bool charging: false

    // Battery detection is done via the SystemService C++ helper
    // (Qt.readFile() is not available in QML, and XMLHttpRequest on file://
    // is disabled in Qt6). The SystemService.hasBattery() method reads
    // /sys/class/power_supply/BAT*/capacity and returns the value, or -1
    // if no battery is present.
    function refresh() {
        var cap = System.batteryCapacity();
        if (cap >= 0) {
            hasBattery = true;
            capacity = cap;
            charging = System.batteryCharging();
        } else {
            hasBattery = false;
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 30000
        running: hasBattery
        repeat: true
        onTriggered: parent.refresh()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusS
        color: Qt.rgba(255,255,255,0.04)
        border.color: Qt.rgba(255,255,255,0.06)
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceXS

            // Battery icon
            Rectangle {
                width: 18
                height: 12
                radius: 2
                color: "transparent"
                border.color: Theme.textSecondary
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: -3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2; height: 4
                    radius: 1
                    color: Theme.textSecondary
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: (parent.width - 2) * (capacity / 100.0)
                    color: capacity > 20 ? Theme.success : Theme.error
                }
            }

            Text {
                text: capacity + "%"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "⚡"
                visible: charging
                color: Theme.warning
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
