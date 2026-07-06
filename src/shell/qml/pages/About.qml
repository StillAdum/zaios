/*
 * About.qml — System info page.
 */
import QtQuick
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
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Version " + zaiosVersion + " (Aurora)"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            anchors.horizontalCenter: parent.horizontalCenter
        }
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
        }
    }

    FocusButton {
        id: backBtn
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceL
        anchors.horizontalCenter: parent.horizontalCenter
        text: "← Back to Settings"
        width: 220; height: 48
        cornerRadius: 24
        onClicked: root.goTo("settings")
    }

    component InfoRow: Row {
        width: parent.width
        spacing: Theme.spaceM

        Text {
            text: label
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            width: parent.width * 0.4
        }
        Text {
            text: value
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.weight: Font.Medium
            font.pixelSize: Theme.fontSizeM
            width: parent.width * 0.6
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
        }
    }
}
