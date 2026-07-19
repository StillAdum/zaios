/*
 * TopBar.qml — Persistent top status bar.
 *
 * Left:   ZAIos logo + current page title
 * Center: clock
 * Right:  network, bluetooth, volume, power badges
 *
 * Clickable badges open the relevant settings page.
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell

Rectangle {
    id: topBar
    color: Qt.rgba(5/255, 8/255, 22/255, 0.7)   // glass deep
    border.color: Qt.rgba(255, 255, 255, 0.06)
    border.width: 1

    // Note: MultiEffect blur removed (needs QtQuick.Effects, not in Qt 6.4)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceL
        anchors.rightMargin: Theme.spaceL
        spacing: Theme.spaceM

        // ── Left: Logo + page title ──────────────────────────────────────
        RowLayout {
            spacing: Theme.spaceS
            Layout.alignment: Qt.AlignLeft

            Image {
                source: "qrc:/icons/zaios-logo.svg"
                sourceSize.width: 28
                sourceSize.height: 28
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
            }

            Text {
                text: "ZAIos"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeL
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "·"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeL
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                id: pageTitle
                text: {
                    var titles = {
                        "home": "Home",
                        "spotify": "Spotify",
                        "youtube": "YouTube",
                        "browser": "Browser",
                        "cast": "Cast",
                        "settings": "Settings",
                        "network": "Network",
                        "bluetooth": "Bluetooth",
                        "about": "About",
                        "apps": "All Apps"
                    };
                    return titles[root.currentPage] || "ZAIos";
                }
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // ── Center: Clock + date ─────────────────────────────────────────
        Item { Layout.fillWidth: true }

        ClockWidget {
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.fillWidth: true }

        // ── Right: Status badges ─────────────────────────────────────────
        RowLayout {
            spacing: Theme.spaceS
            Layout.alignment: Qt.AlignRight

            NetworkBadge {
                onClicked: root.goTo("network")
            }

            BatteryBadge {}

            // Bluetooth badge
            Rectangle {
                width: 36; height: 36
                radius: Theme.radiusS
                color: btArea.containsMouse ? Qt.rgba(255,255,255,0.08) : "transparent"
                border.color: Qt.rgba(255,255,255,0.06)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "🔵"   // Will be replaced with SVG icon in production
                    font.pixelSize: 18
                    opacity: Bluetooth.powered ? 1.0 : 0.4
                }
                MouseArea {
                    id: btArea
                    anchors.fill: parent
                    onClicked: root.goTo("bluetooth")
                }
            }

            // Volume badge
            Rectangle {
                width: 36; height: 36
                radius: Theme.radiusS
                color: volArea.containsMouse ? Qt.rgba(255,255,255,0.08) : "transparent"
                border.color: Qt.rgba(255,255,255,0.06)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: Settings.muted ? "🔇" : (Settings.volume > 50 ? "🔊" : "🔉")
                    font.pixelSize: 18
                }
                MouseArea {
                    id: volArea
                    anchors.fill: parent
                    onClicked: root.showVolumeOverlay()
                }
            }

            // Power button
            Rectangle {
                width: 36; height: 36
                radius: Theme.radiusS
                color: pwrArea.containsMouse ? Qt.rgba(255,61,90,0.2) : "transparent"
                border.color: Qt.rgba(255,61,90,0.3)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    color: Theme.error
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: pwrArea
                    anchors.fill: parent
                    onClicked: root.powerMenuVisible = true
                }
            }
        }
    }
}
