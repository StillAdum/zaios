/*
 * FocusButton.qml — A button designed for D-pad navigation.
 *
 * Standard QML Buttons work with mouse/touch but don't always pick up focus
 * nicely on TV remotes. FocusButton explicitly:
 *   - accepts focus on hover (so cursor-mode users get visual feedback too)
 *   - magnifies slightly on focus
 *   - glows with accent color when focused
 *   - emits clicked() on Enter/Return key as well as mouse click
 *
 * Designed to be wrapped in a FocusScope by the parent layout (e.g. RowLayout,
 * GridLayout, ListView) so that Up/Down/Left/Right work as expected.
 */
import QtQuick
import QtQuick.Controls
import ZAIos.Shell
import "../styles"

Button {
    id: btn

    property color bgColor: Qt.rgba(30/255, 40/255, 81/255, 0.7)
    property color bgColorFocused: Qt.rgba(0, 229/255, 1, 0.2)
    property color textColor: Theme.textPrimary
    property color textColorFocused: Theme.accent
    property int   cornerRadius: Theme.radiusM
    property bool  glowOnFocus: true
    property real  scaleOnFocus: 1.05

    focusPolicy: Qt.StrongFocus

    background: Item {
        anchors.fill: parent

        // Glow halo (under the button)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: btn.cornerRadius + 6
            color: Qt.rgba(0, 229/255, 1, 0.3)
            visible: btn.activeFocus && btn.glowOnFocus
            opacity: 0.5
            z: -1
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // Body
        Rectangle {
            anchors.fill: parent
            radius: btn.cornerRadius
            color: btn.activeFocus ? btn.bgColorFocused : btn.bgColor
            border.color: btn.activeFocus ? Theme.accent : Qt.rgba(255,255,255,0.08)
            border.width: btn.activeFocus ? 2 : 1

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    contentItem: Text {
        text: btn.text
        color: btn.activeFocus ? btn.textColorFocused : btn.textColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeM
        font.weight: btn.activeFocus ? Font.Bold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Subtle scale on focus
    scale: activeFocus ? scaleOnFocus : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingSpring } }

    // Enter/Return triggers click
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed:  clicked()
    Keys.onSpacePressed:  clicked()

    // Hover also focuses (cursor mode)
    onHoveredChanged: if (hovered) forceActiveFocus()
}
