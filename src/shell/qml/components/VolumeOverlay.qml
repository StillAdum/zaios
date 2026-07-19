/*
 * VolumeOverlay.qml — Volume slider that appears on volume key press.
 *
 * Vertical bar with neon cyan fill, shown on the right side of the screen.
 * Auto-hides after 1.5s (handled by main.qml's timer).
 */
import QtQuick
import ZAIos.Shell
import "../styles"

GlassCard {
    id: overlay
    width: 64
    height: 280
    radius: Theme.radiusL
    glow: true
    focusedOverride: true

    Column {
        anchors.fill: parent
        anchors.topMargin: Theme.spaceM
        anchors.bottomMargin: Theme.spaceM
        spacing: Theme.spaceS

        // Volume icon (top)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Settings.muted ? "🔇" : (Settings.volume > 50 ? "🔊" : "🔉")
            font.pixelSize: 24
        }

        // Vertical track
        Item {
            width: parent.width
            height: parent.height - 80
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                id: track
                anchors.centerIn: parent
                width: 6
                height: parent.height
                radius: 3
                color: Qt.rgba(255, 255, 255, 0.1)
            }

            Rectangle {
                id: fill
                anchors.bottom: track.bottom
                anchors.horizontalCenter: track.horizontalCenter
                width: track.width
                height: track.height * (Settings.volume / 100.0)
                radius: track.radius
                color: Settings.muted ? Theme.textMuted : Theme.accent

                Behavior on height { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingStandard } }
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            // Glow at top of fill
            Rectangle {
                anchors.bottom: fill.top
                anchors.horizontalCenter: fill.horizontalCenter
                width: 14
                height: 14
                radius: 7
                color: Settings.muted ? Theme.textMuted : Theme.accent
                opacity: 0.7
            }
        }

        // Volume %
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Settings.muted ? "M" : Settings.volume + "%"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
        }
    }
}
