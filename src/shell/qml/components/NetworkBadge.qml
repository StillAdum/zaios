/*
 * NetworkBadge.qml — Network status indicator for the top bar.
 *
 * Shows WiFi signal strength bars + SSID when connected, or "No network"
 * when not. Clicking opens the Network settings page.
 */
import QtQuick
import ZAIos.Shell
import "../styles"

Item {
    width: 110
    height: 36

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusS
        color: ma.containsMouse ? Qt.rgba(255,255,255,0.08) : "transparent"
        border.color: Qt.rgba(255,255,255,0.06)
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceS

            // Signal bars
            Row {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 4
                    Rectangle {
                        width: 3
                        height: 4 + index * 4
                        radius: 1
                        color: signalStrength() > index ? Theme.accent : Qt.rgba(255,255,255,0.2)
                        anchors.bottom: parent.bottom

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }
                }
            }

            Text {
                text: Network.connected ? "WiFi" : "Off"
                color: Network.connected ? Theme.textPrimary : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: 50
            }
        }
    }

    function signalStrength() {
        if (!Network.connected) return 0;
        // Heuristic from Network.state (wpa_supplicant states)
        if (Network.state === "COMPLETED") return 4;
        return 2;
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: parent.clicked()
    }
}
