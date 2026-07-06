/*
 * Network.qml — Wi-Fi network settings.
 *
 * Shows:
 *   - Current connection state
 *   - Scan button
 *   - List of available networks with signal strength + security
 *   - Click to connect (password prompt if secured)
 *
 * Uses NetworkManager (which talks to zaios-network service → wpa_supplicant).
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: netPage
    anchors.fill: parent

    property string connectingSsid: ""
    property string passwordForSsid: ""

    Component.onCompleted: {
        Network.refreshStatus();
        scanBtn.forceActiveFocus();
    }

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
            text: "Network"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXXL
        }

        Item { width: 100; height: 1 }

        FocusButton {
            id: scanBtn
            text: Network.scanning ? "Scanning..." : "🔄 Scan"
            width: 160; height: 48
            cornerRadius: 24
            onClicked: Network.scan()
        }
    }

    // ── Current connection state ─────────────────────────────────────────
    GlassCard {
        id: stateCard
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceL
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXXL
        height: 80
        radius: Theme.radiusL
        glow: Network.connected

        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceL

            Text {
                text: Network.connected ? "✓" : "⚠"
                color: Network.connected ? Theme.success : Theme.warning
                font.pixelSize: 32
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: Network.connected ? "Connected" : "Not Connected"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSizeL
                }
                Text {
                    text: Network.connected ?
                            (Network.ssid + "  •  " + Network.ip) :
                            "Connect to a network below"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                }
            }
        }
    }

    // ── Network list ─────────────────────────────────────────────────────
    GlassCard {
        anchors.top: stateCard.bottom
        anchors.topMargin: Theme.spaceL
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXXL
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceXXL
        radius: Theme.radiusL

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            spacing: Theme.spaceS

            Text {
                text: "AVAILABLE NETWORKS"
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
                    id: netList
                    model: Network.networks
                    spacing: Theme.spaceS

                    delegate: FocusButton {
                        width: netList.width
                        height: 72
                        cornerRadius: Theme.radiusM
                        text: ""

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceM
                            anchors.rightMargin: Theme.spaceM
                            spacing: Theme.spaceM

                            // Signal bars
                            Column {
                                width: 24
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: 16; height: 4
                                        radius: 1
                                        color: getSignal(modelData.ssid, modelData.signal) > index ?
                                               Theme.accent : Qt.rgba(255,255,255,0.2)
                                    }
                                }
                            }

                            // Network info
                            Column {
                                width: parent.width - 24 - Theme.spaceM*2 - 60
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: modelData.ssid || "(hidden)"
                                    color: parent.parent.activeFocus ? Theme.accent : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: Theme.fontSizeM
                                    elide: Text.ElideRight
                                    width: parent.width

                                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                }
                                Text {
                                    text: (modelData.flags || "").replace(/\[WPA/, "🔒 WPA").replace(/\]/g, "") +
                                          "  •  " + modelData.signal + " dBm"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeS
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            // Connect button / status
                            Text {
                                text: Network.ssid === modelData.ssid ? "✓ Connected" : "Connect →"
                                color: Network.ssid === modelData.ssid ? Theme.success :
                                       parent.parent.activeFocus ? Theme.accent : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.weight: Font.Medium
                                font.pixelSize: Theme.fontSizeS
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: {
                            // If secured, show password prompt
                            if ((modelData.flags || "").indexOf("WPA") >= 0) {
                                passwordPrompt.ssid = modelData.ssid;
                                passwordPrompt.visible = true;
                                passwordInput.forceActiveFocus();
                            } else {
                                Network.connect(modelData.ssid, "");
                            }
                        }
                    }
                }
            }
        }
    }

    function getSignal(ssid, dbm) {
        if (dbm > -50) return 4;
        if (dbm > -60) return 3;
        if (dbm > -70) return 2;
        return 1;
    }

    // ── Password prompt (overlay) ────────────────────────────────────────
    Rectangle {
        id: passwordPrompt
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: false

        property string ssid: ""

        GlassCard {
            anchors.centerIn: parent
            width: 500
            height: 280
            radius: Theme.radiusXL
            glow: true

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceXL
                spacing: Theme.spaceM

                Text {
                    text: "Enter password for:"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                }
                Text {
                    text: passwordPrompt.ssid
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSizeL
                }

                TextField {
                    id: passwordInput
                    width: parent.width
                    height: 56
                    echoMode: TextInput.Password
                    placeholderText: "Password"
                    placeholderTextColor: Theme.textMuted
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    selectByMouse: true

                    background: Rectangle {
                        radius: Theme.radiusM
                        color: Qt.rgba(0,0,0,0.3)
                        border.color: passwordInput.activeFocus ? Theme.accent : Qt.rgba(255,255,255,0.1)
                        border.width: passwordInput.activeFocus ? 2 : 1
                    }

                    Keys.onReturnPressed: doConnect()
                    Keys.onEnterPressed:  doConnect()

                    function doConnect() {
                        Network.connect(passwordPrompt.ssid, text);
                        passwordPrompt.visible = false;
                        passwordInput.text = "";
                    }
                }

                Row {
                    spacing: Theme.spaceM
                    anchors.horizontalCenter: parent.horizontalCenter

                    FocusButton {
                        text: "Cancel"
                        width: 140; height: 48
                        cornerRadius: 24
                        onClicked: {
                            passwordPrompt.visible = false;
                            passwordInput.text = "";
                        }
                    }
                    FocusButton {
                        text: "Connect"
                        width: 140; height: 48
                        cornerRadius: 24
                        bgColor: Theme.accent
                        textColor: Theme.bgDeep
                        onClicked: passwordInput.doConnect()
                    }
                }
            }
        }
    }
}
