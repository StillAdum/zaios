/*
 * Settings.qml — Settings hub.
 *
 * Categories: Network, Bluetooth, Display & Sound, Apps, System, About
 * Each item navigates to its own page.
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell
import "../components"
import "../styles"

Item {
    id: settingsPage
    anchors.fill: parent

    Component.onCompleted: settingsGrid.children[0].forceActiveFocus();

    // ── Header ───────────────────────────────────────────────────────────
    Text {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        text: "Settings"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSizeXXL
    }

    // ── Settings grid ────────────────────────────────────────────────────
    GridLayout {
        id: settingsGrid
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXL
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXXL
        columns: 3
        rowSpacing: Theme.spaceL
        columnSpacing: Theme.spaceL

        // ── Network ──────────────────────────────────────────────────────
        SettingsTile {
            iconText: "📶"
            cardTitle: "Network"
            subtitle: Network.connected ? "Connected to " + Network.ssid : "Not connected"
            accentColor: Theme.accent
            onActivated: root.goTo("network")
        }

        // ── Bluetooth ────────────────────────────────────────────────────
        SettingsTile {
            iconText: "🔵"
            cardTitle: "Bluetooth"
            subtitle: Bluetooth.powered ? "On" : "Off"
            accentColor: Theme.accent
            onActivated: root.goTo("bluetooth")
        }

        // ── Display & Sound ──────────────────────────────────────────────
        SettingsTile {
            iconText: "📺"
            cardTitle: "Display & Sound"
            subcardTitle: "Volume: " + Settings.volume + "%"
            accentColor: Theme.accentSoft
            onActivated: {} // Could open a sub-page
        }

        // ── Apps ─────────────────────────────────────────────────────────
        SettingsTile {
            iconText: "▦"
            cardTitle: "Apps"
            subcardTitle: "Manage installed apps"
            accentColor: Theme.accentPurple
            onActivated: root.goTo("apps")
        }

        // ── Language ─────────────────────────────────────────────────────
        SettingsTile {
            iconText: "🌐"
            cardTitle: "Language"
            subcardTitle: "English"
            accentColor: Theme.accentSoft
            onActivated: {} // TODO: language picker
        }

        // ── Hostname ─────────────────────────────────────────────────────
        SettingsTile {
            iconText: "🏷"
            cardTitle: "Device Name"
            subtitle: Settings.hostname
            accentColor: Theme.accent
            onActivated: {} // TODO: hostname editor
        }

        // ── About ────────────────────────────────────────────────────────
        SettingsTile {
            iconText: "ⓘ"
            cardTitle: "About"
            subcardTitle: "ZAIos " + zaiosVersion
            accentColor: Theme.textSecondary
            onActivated: root.goTo("about")
        }

        // ── Reboot ───────────────────────────────────────────────────────
        SettingsTile {
            iconText: "↻"
            cardTitle: "Restart"
            subcardTitle: "Reboot the device"
            accentColor: Theme.warning
            onActivated: Power.reboot()
        }

        // ── Power Off ────────────────────────────────────────────────────
        SettingsTile {
            iconText: "⏻"
            cardTitle: "Power Off"
            subcardTitle: "Shut down"
            accentColor: Theme.error
            onActivated: Power.powerOff()
        }
    }

    component SettingsTile: FocusButton {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 120
        cornerRadius: Theme.radiusL
        text: ""
        scaleOnFocus: 1.03

        property string iconText: ""
        property string cardTitle: ""
        property string subcardTitle: ""
        property color  accentColor: Theme.accent
        signal activated()

        onClicked: activated()

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            spacing: Theme.spaceM

            Rectangle {
                width: 64; height: 64
                radius: 16
                color: Qt.rgba(parent.parent.accentColor.r, parent.parent.accentColor.g, parent.parent.accentColor.b, 0.15)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: parent.parent.parent.iconText
                    font.pixelSize: 32
                }
            }

            Column {
                width: parent.width - 64 - Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: parent.parent.parent.cardTitle
                    color: parent.parent.activeFocus ? parent.parent.accentColor : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSizeL
                    elide: Text.ElideRight
                    width: parent.width

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                Text {
                    text: parent.parent.parent.subtitle
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }
}
