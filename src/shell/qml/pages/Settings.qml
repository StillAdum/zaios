/*
 * Settings.qml — Settings hub.
 *
 * Categories: Network, Bluetooth, Display & Sound, Apps, System, About
 * Each item navigates to its own page.
 */
import QtQuick
import "../components"
import "../styles"
import QtQuick.Layouts
import ZAIos.Shell

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
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXXL
        columns: 3
        rowSpacing: Theme.spaceL
        columnSpacing: Theme.spaceL
        // ── Network ──────────────────────────────────────────────────────
        SettingsTile {
            icon: "📶"
            title: "Network"
            subtitle: Network.connected ? "Connected to " + Network.ssid : "Not connected"
            accentColor: Theme.accent
            onActivated: root.goTo("network")
        }
        // ── Bluetooth ────────────────────────────────────────────────────
            icon: "🔵"
            title: "Bluetooth"
            subtitle: Bluetooth.powered ? "On" : "Off"
            onActivated: root.goTo("bluetooth")
        // ── Display & Sound ──────────────────────────────────────────────
            icon: "📺"
            title: "Display & Sound"
            subtitle: "Volume: " + Settings.volume + "%"
            accentColor: Theme.accentSoft
            onActivated: {} // Could open a sub-page
        // ── Apps ─────────────────────────────────────────────────────────
            icon: "▦"
            title: "Apps"
            subtitle: "Manage installed apps"
            accentColor: Theme.accentPurple
            onActivated: root.goTo("apps")
        // ── Language ─────────────────────────────────────────────────────
            icon: "🌐"
            title: "Language"
            subtitle: "English"
            onActivated: {} // TODO: language picker
        // ── Hostname ─────────────────────────────────────────────────────
            icon: "🏷"
            title: "Device Name"
            subtitle: Settings.hostname
            onActivated: {} // TODO: hostname editor
        // ── About ────────────────────────────────────────────────────────
            icon: "ⓘ"
            title: "About"
            subtitle: "ZAIos " + zaiosVersion
            accentColor: Theme.textSecondary
            onActivated: root.goTo("about")
        // ── Reboot ───────────────────────────────────────────────────────
            icon: "↻"
            title: "Restart"
            subtitle: "Reboot the device"
            accentColor: Theme.warning
            onActivated: Power.reboot()
        // ── Power Off ────────────────────────────────────────────────────
            icon: "⏻"
            title: "Power Off"
            subtitle: "Shut down"
            accentColor: Theme.error
            onActivated: Power.powerOff()
    component SettingsTile: FocusButton {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 120
        cornerRadius: Theme.radiusL
        text: ""
        scaleOnFocus: 1.03
        property string icon: ""
        property string title: ""
        property string subtitle: ""
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
                    text: parent.parent.parent.icon
                    font.pixelSize: 32
                }
            }
            Column {
                width: parent.width - 64 - Theme.spaceM
                spacing: 4
                    text: parent.parent.parent.title
                    color: parent.parent.activeFocus ? parent.parent.accentColor : Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSizeL
                    elide: Text.ElideRight
                    width: parent.width
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    text: parent.parent.parent.subtitle
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeS
}
