/*
 * About.qml — System info page.
 */
import QtQuick
import "../components"
import "../styles"
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: aboutPage
    anchors.fill: parent
    Component.onCompleted: backBtn.forceActiveFocus();
    Column {
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL
        // Logo
        Image {
            source: "qrc:/icons/zaios-logo.svg"
            sourceSize.width: 120
            sourceSize.height: 120
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "ZAIos"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXXXL
            text: "Version " + zaiosVersion + " (Aurora)"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeL
    }
    // ── System info card ─────────────────────────────────────────────────
    GlassCard {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 80
        width: 600
        height: 320
        radius: Theme.radiusXL
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spaceXL
            spacing: Theme.spaceM
            InfoRow { label: "OS Name";       value: System.osName }
            InfoRow { label: "OS Version";    value: System.osVersion }
            InfoRow { label: "Kernel";        value: System.kernelVersion }
            InfoRow { label: "Hostname";      value: System.hostname }
            InfoRow { label: "Uptime";        value: System.uptime }
            InfoRow { label: "CPU Usage";     value: System.cpuUsage + "%" }
            InfoRow { label: "Memory";        value: System.memUsage + "% of " + System.memTotalMb + " MB" }
            InfoRow { label: "Disk";          value: System.diskUsed + "% of " + System.diskTotal + " GB" }
    FocusButton {
        id: backBtn
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceL
        text: "← Back to Settings"
        width: 220; height: 48
        cornerRadius: 24
        onClicked: root.goTo("settings")
    component InfoRow: Row {
        width: parent.width
        spacing: Theme.spaceM
            text: label
            font.pixelSize: Theme.fontSizeM
            width: parent.width * 0.4
            text: value
            color: Theme.textPrimary
            font.weight: Font.Medium
            width: parent.width * 0.6
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
}
