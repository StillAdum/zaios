/*
 * BatteryBadge.qml - Battery status indicator.
 *
 * Reads /sys/class/power_supply/BAT-something/capacity and status.
 * Most TVs don't have a battery, so this hides itself if no battery found.
 */
import QtQuick
import ZAIos.Shell

Item {
    width: 56
    height: 36
    visible: hasBattery

    property bool hasBattery: false
    property int  capacity: 0
    property bool charging: false

    function refresh() {
        var req = new XMLHttpRequest();
        req.open("GET", "file:///sys/class/power_supply/BAT0/capacity", true);
        req.onreadystatechange = function() {
            if (req.readyState === 4 && req.status === 0 && req.responseText.length > 0) {
                hasBattery = true;
                capacity = parseInt(req.responseText.trim());
            }
        };
        req.send();

        var st = new XMLHttpRequest();
        st.open("GET", "file:///sys/class/power_supply/BAT0/status", true);
        st.onreadystatechange = function() {
            if (st.readyState === 4) {
                charging = (st.responseText.trim() === "Charging");
            }
        };
        st.send();
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
