/*
 * GlassCard.qml — Reusable frosted-glass card container.
 *
 * Properties:
 *   - radius: corner radius (default Theme.radiusL)
 *   - glow:   when true, adds accent glow when focused
 *   - focusedOverride: manually trigger focus glow (for active items)
 *
 * The card has:
 *   - 1px subtle white border at low opacity
 *   - Linear gradient from glass-light (top) to glass-dark (bottom)
 *   - Blur over content behind (MultiEffect)
 *   - Soft drop shadow underneath
 *   - On focus: brightens + adds cyan glow
 */
import QtQuick
import ZAIos.Shell
import "../styles"

Item {
    id: cardRoot
    default property alias content: contentItem.children

    property int radius: Theme.radiusL
    property bool glow: false
    property bool focusedOverride: false
    property bool focused: activeFocus || focusedOverride
    property color borderColor: Qt.rgba(255, 255, 255, 0.06)
    property color borderColorFocused: Qt.rgba(0, 229/255, 1, 0.5)

    Behavior on scale {
        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingStandard }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingStandard }
    }

    // ── Drop shadow (under the card) ─────────────────────────────────────
    Rectangle {
        id: shadowRect
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: cardRoot.radius + 4
        color: "transparent"
        visible: false
    }

    // ── Card body ────────────────────────────────────────────────────────
    Rectangle {
        id: bodyRect
        anchors.fill: parent
        radius: cardRoot.radius

        // Glass gradient
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(30/255, 40/255, 81/255, cardRoot.focused ? 0.85 : 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(11/255, 18/255, 48/255, cardRoot.focused ? 0.95 : 0.85) }
        }

        border.color: cardRoot.focused ? cardRoot.borderColorFocused : cardRoot.borderColor
        border.width: cardRoot.focused ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.width { NumberAnimation { duration: Theme.durationFast } }

        // Inner highlight (top edge)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(255, 255, 255, cardRoot.focused ? 0.2 : 0.05)
        }
    }

    // ── Focus glow overlay ───────────────────────────────────────────────
    Rectangle {
        id: glowOverlay
        anchors.fill: parent
        anchors.margins: -8
        radius: cardRoot.radius + 8
        color: Qt.rgba(0, 229/255, 1, 0.15)
        visible: cardRoot.focused && cardRoot.glow
        z: -1

        Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }
    }

    // ── Content slot ─────────────────────────────────────────────────────
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: 0
        clip: true
    }
}
