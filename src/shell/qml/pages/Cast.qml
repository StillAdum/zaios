/*
 * Cast.qml — Miracast (Wi-Fi Display) receiver page.
 *
 * Shows:
 *   - Sink state (stopped / listening / connected)
 *   - Start/Stop button
 *   - List of pending peers (waiting to connect)
 *   - Accept/Reject buttons per peer
 *
 * Also includes a brief explainer that this is Miracast, not Google Cast
 * (which is proprietary).
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: castPage
    anchors.fill: parent

    Component.onCompleted: startBtn.forceActiveFocus();

    // ── Header ───────────────────────────────────────────────────────────
    Column {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceS

        Text {
            text: "📡 Cast Receiver"
            color: Theme.accentPurple
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXXL
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Receive Miracast (Wi-Fi Display) from Windows, Android, and more"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── State indicator ──────────────────────────────────────────────────
    GlassCard {
        id: stateCard
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXXL
        anchors.horizontalCenter: parent.horizontalCenter
        width: 600
        height: 200
        radius: Theme.radiusXL
        glow: Cast.state !== "stopped"

        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceXL

            // State icon
            Rectangle {
                width: 100; height: 100
                radius: 50
                color: {
                    if (Cast.state === "connected") return Theme.success;
                    if (Cast.state === "listening") return Theme.accent;
                    if (Cast.state === "starting")  return Theme.warning;
                    return Theme.textMuted;
                }
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                // Pulse animation when listening
                SequentialAnimation on scale {
                    running: Cast.state === "listening"
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.15; duration: 1000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                }

                Text {
                    anchors.centerIn: parent
                    text: "📡"
                    font.pixelSize: 50
                }
            }

            Column {
                spacing: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: Cast.state === "stopped"    ? "Receiver Off" :
                          Cast.state === "starting"   ? "Starting..." :
                          Cast.state === "listening"  ? "Ready to Cast" :
                                                        "Connected"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSizeXL
                }

                Text {
                    text: Cast.state === "listening" ?
                            "Open the cast menu on your phone or PC" :
                          Cast.state === "connected" ?
                            "Streaming in progress" :
                            "Press Start to begin receiving"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                }
            }
        }
    }

    // ── Start/Stop button ────────────────────────────────────────────────
    FocusButton {
        id: startBtn
        anchors.top: stateCard.bottom
        anchors.topMargin: Theme.spaceL
        anchors.horizontalCenter: parent.horizontalCenter
        width: 240; height: 64
        cornerRadius: Theme.radiusPill
        text: Cast.state === "stopped" ? "▶ Start Receiver" : "⏹ Stop Receiver"
        bgColor: Cast.state === "stopped" ? Theme.accent : Theme.error
        bgColorFocused: Cast.state === "stopped" ? Theme.accentSoft : "#FF5566"
        textColor: Theme.bgDeep
        textColorFocused: Theme.bgDeep
        scaleOnFocus: 1.04
        onClicked: {
            if (Cast.state === "stopped") Cast.start();
            else Cast.stop();
        }
    }

    // ── Pending peers list ───────────────────────────────────────────────
    GlassCard {
        anchors.top: startBtn.bottom
        anchors.topMargin: Theme.spaceXXL
        anchors.horizontalCenter: parent.horizontalCenter
        width: 600
        height: 240
        radius: Theme.radiusL
        visible: Cast.peers.length > 0

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spaceM
            spacing: Theme.spaceS

            Text {
                text: "PENDING CONNECTIONS"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeS
                letterSpacing: 2
            }

            ListView {
                width: parent.width
                height: parent.height - 32
                model: Cast.peers
                spacing: Theme.spaceS
                clip: true

                delegate: Row {
                    width: parent.width
                    spacing: Theme.spaceM

                    Text {
                        text: modelData.name || modelData.peer
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeM
                        width: parent.width - 200
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    FocusButton {
                        text: "Accept"
                        width: 90; height: 36
                        cornerRadius: 18
                        bgColor: Theme.success
                        onClicked: Cast.accept(modelData.peer)
                    }
                    FocusButton {
                        text: "Reject"
                        width: 90; height: 36
                        cornerRadius: 18
                        bgColor: Theme.error
                        onClicked: Cast.reject(modelData.peer)
                    }
                }
            }
        }
    }

    // ── Note about Miracast vs Google Cast ───────────────────────────────
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceL
        anchors.horizontalCenter: parent.horizontalCenter
        text: "ℹ Miracast is the open Wi-Fi Display standard. To cast from Chrome/iOS, use the in-OS Browser."
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeXS
    }
}
