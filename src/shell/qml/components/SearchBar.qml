/*
 * SearchBar.qml — Reusable search input with glass styling.
 *
 * Used by Spotify, YouTube, Browser pages.
 *
 * Focus-aware: when focused, the bar widens slightly and the accent border lights up.
 * Emits searchSubmitted(text) on Enter or after 800ms of typing.
 */
import QtQuick
import QtQuick.Controls
import ZAIos.Shell

FocusScope {
    id: searchRoot
    width: 600
    height: 56

    property string placeholder: "Search..."
    signal searchSubmitted(string query)
    signal searchChanged(string query)

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusPill
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(30/255, 40/255, 81/255, 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(11/255, 18/255, 48/255, 0.85) }
        }
        border.color: input.activeFocus ? Theme.accent : Qt.rgba(255,255,255,0.08)
        border.width: input.activeFocus ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Search icon (left)
    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        text: "🔍"
        font.pixelSize: 20
        opacity: 0.7
    }

    TextField {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 48
        anchors.rightMargin: 48
        verticalAlignment: Text.AlignVCenter
        placeholderText: searchRoot.placeholder
        placeholderTextColor: Theme.textMuted
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeM
        selectByMouse: true

        background: Item {}

        onTextChanged: {
            searchRoot.searchChanged(text);
            debounceTimer.restart();
        }
        Keys.onReturnPressed: searchRoot.searchSubmitted(text)
        Keys.onEnterPressed:  searchRoot.searchSubmitted(text)
    }

    // Clear button (right)
    Item {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Theme.textMuted
            font.pixelSize: 16
            opacity: input.text.length > 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                input.text = "";
                input.forceActiveFocus();
            }
        }
    }

    // Debounce typing — emit searchSubmitted 800ms after last keystroke
    Timer {
        id: debounceTimer
        interval: 800
        onTriggered: {
            if (input.text.length > 1) {
                searchRoot.searchSubmitted(input.text);
            }
        }
    }
}
