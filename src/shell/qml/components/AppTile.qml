/*
 * AppTile.qml — A large square app tile for the home grid.
 *
 * Properties:
 *   - appId: identifier used for navigation
 *   - appName: display title
 *   - appIcon: emoji or path to SVG icon
 *   - accentColor: tile color accent (defaults to Theme.accent)
 *
 * Behavior:
 *   - On focus: tile scales up slightly, glows, icon bounces
 *   - On click/Enter: emits launched(appId)
 *   - On hover (cursor mode): tile picks up focus
 */
import QtQuick
import QtQuick.Controls
import ZAIos.Shell
import "../styles"

Item {
    id: tile
    width: 220
    height: 280

    property string appId: ""
    property string appName: ""
    property string appIcon: "📺"
    property string appSubtitle: ""
    property color  accentColor: Theme.accent
    property bool   active: activeFocus

    signal launched(string appId)

    FocusButton {
        id: btn
        anchors.fill: parent
        text: ""
        cornerRadius: Theme.radiusL
        bgColor: Qt.rgba(30/255, 40/255, 81/255, 0.7)
        bgColorFocused: Qt.rgba(0, 229/255, 1, 0.15)
        scaleOnFocus: 1.04

        onClicked: tile.launched(tile.appId)
    }

    // ── Tile content (drawn over the button) ─────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: Theme.spaceM
        anchors.bottomMargin: Theme.spaceL

        Column {
            anchors.fill: parent
            spacing: Theme.spaceS

            // ── Icon area ─────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 120

                // Glow behind icon when focused
                Rectangle {
                    anchors.centerIn: iconText
                    width: 80; height: 80
                    radius: 40
                    color: Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.3)
                    visible: tile.active
                    scale: tile.active ? 1.4 : 1.0
                    opacity: tile.active ? 1.0 : 0.0
                    Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingSpring } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
                }

                Text {
                    id: iconText
                    anchors.centerIn: parent
                    text: tile.appIcon
                    font.pixelSize: 64
                    scale: tile.active ? 1.15 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingSpring } }
                }
            }

            // ── Title ─────────────────────────────────────────────────────
            Text {
                text: tile.appName
                color: tile.active ? tile.accentColor : Theme.textPrimary
                font.family: Theme.fontFamily
                font.weight: tile.active ? Font.Bold : Font.Medium
                font.pixelSize: Theme.fontSizeL
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            // ── Subtitle (optional) ───────────────────────────────────────
            Text {
                text: tile.appSubtitle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }

    // ── Bottom accent line (lit when focused) ────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: tile.active ? parent.width * 0.6 : 0
        height: 3
        radius: 2
        color: tile.accentColor
        Behavior on width { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easingSpring } }
    }

    // Accept input focus on hover (cursor mode)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tile.launched(tile.appId)
        onEntered: btn.forceActiveFocus()
    }
}
