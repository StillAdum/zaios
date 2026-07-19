/*
 * Bluetooth.qml — Bluetooth device management.
 *
 * Shows:
 *   - Adapter power toggle
 *   - Scan button
 *   - List of paired/discovered devices
 *   - Connect/Disconnect/Pair buttons per device
 */
import QtQuick
import "../components"
import "../styles"
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: btPage
    anchors.fill: parent
    Component.onCompleted: scanBtn.forceActiveFocus();
    // ── Header ───────────────────────────────────────────────────────────
    Row {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXXL
        spacing: Theme.spaceL
        Text {
            text: "Bluetooth"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXXL
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 100; height: 1 }
        FocusButton {
            text: Bluetooth.powered ? "🔵 On" : "⚪ Off"
            width: 140; height: 48
            cornerRadius: 24
            bgColor: Bluetooth.powered ? Theme.accent : Qt.rgba(255,255,255,0.05)
            textColor: Bluetooth.powered ? Theme.bgDeep : Theme.textPrimary
            onClicked: Bluetooth.setPowered(!Bluetooth.powered)
            id: scanBtn
            text: Bluetooth.scanning ? "Scanning..." : "🔄 Scan"
            width: 160; height: 48
            onClicked: Bluetooth.startScan()
    }
    // ── Device list ──────────────────────────────────────────────────────
    GlassCard {
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceL
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceXXL
        radius: Theme.radiusL
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            spacing: Theme.spaceS
            Text {
                text: "DEVICES"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeS
                letterSpacing: 2
            }
            ScrollView {
                width: parent.width
                height: parent.height - 32
                clip: true
                ListView {
                    id: devList
                    model: Bluetooth.devices
                    spacing: Theme.spaceS
                    delegate: FocusButton {
                        width: devList.width
                        height: 80
                        cornerRadius: Theme.radiusM
                        text: ""
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceM
                            anchors.rightMargin: Theme.spaceM
                            spacing: Theme.spaceM
                            // Device icon
                            Rectangle {
                                width: 56; height: 56
                                radius: 28
                                color: modelData.connected ? Theme.accent : Qt.rgba(255,255,255,0.05)
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        var icon = modelData.icon || "phone";
                                        if (icon.indexOf("audio") >= 0) return "🎧";
                                        if (icon.indexOf("keyboard") >= 0) return "⌨";
                                        if (icon.indexOf("mouse") >= 0) return "🖱";
                                        if (icon.indexOf("gamepad") >= 0) return "🎮";
                                        return "📱";
                                    }
                                    font.pixelSize: 24
                                }
                            }
                            // Device info
                            Column {
                                width: parent.width - 56 - Theme.spaceM*2 - 200
                                spacing: 2
                                    text: modelData.name || modelData.address
                                    color: parent.parent.activeFocus ? Theme.accent : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: Theme.fontSizeM
                                    elide: Text.ElideRight
                                    width: parent.width
                                    text: modelData.paired ? "Paired" : "Not paired"
                                    color: modelData.connected ? Theme.success : Theme.textMuted
                                    font.pixelSize: Theme.fontSizeS
                            // Actions
                            Row {
                                spacing: Theme.spaceS
                                FocusButton {
                                    text: modelData.connected ? "Disconnect" :
                                          modelData.paired ? "Connect" : "Pair"
                                    width: 120; height: 40
                                    cornerRadius: 20
                                    bgColor: modelData.connected ? Theme.error :
                                             modelData.paired ? Theme.success : Theme.accent
                                    onClicked: {
                                        if (modelData.connected) Bluetooth.disconnectFromDevice(modelData.path);
                                        else if (modelData.paired) Bluetooth.connectToDevice(modelData.path);
                                        else Bluetooth.pair(modelData.path);
                        }
                    }
                }
}
