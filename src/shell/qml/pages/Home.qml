/*
 * Home.qml — The ZAIos home screen.
 *
 * Layout:
 *   - Big greeting header ("Good evening, User")
 *   - Quick-action row (recently used apps)
 *   - Main app grid (Spotify, YouTube, Browser, Cast, Settings, All Apps)
 *   - Footer hint (D-pad nav keys)
 *
 * D-pad nav: Up/Down/Left/Right between tiles, OK to launch.
 * Cursor mode: click tiles directly.
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: homeRoot
    anchors.fill: parent

    property var appTiles: []

    Component.onCompleted: {
        // Focus the first tile by default
        if (appGrid.children.length > 0) {
            appGrid.children[0].forceActiveFocus();
        }
    }

    // Greeting
    Item {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        anchors.right: parent.right
        height: 140

        Text {
            id: greetingText
            text: getGreeting()
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXXL

            // Entry animation
            NumberAnimation on opacity { from: 0; to: 1; duration: Theme.durationSlow }
            NumberAnimation on x { from: -50; to: 0; duration: Theme.durationSlow; easing.type: Theme.easingStandard }
        }

        Text {
            id: subtitle
            anchors.top: greetingText.bottom
            anchors.topMargin: Theme.spaceS
            text: "What would you like to watch today?"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL

            NumberAnimation on opacity { from: 0; to: 1; duration: Theme.durationSlow; }
            NumberAnimation on x { from: -30; to: 0; duration: Theme.durationSlow; easing.type: Theme.easingStandard }
        }

        function getGreeting() {
            var h = new Date().getHours();
            if (h < 12) return "Good morning";
            if (h < 18) return "Good afternoon";
            return "Good evening";
        }
    }

    // ── Main app grid ────────────────────────────────────────────────────
    GridLayout {
        id: appGrid
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXXL
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 4
        rowSpacing: Theme.spaceXL
        columnSpacing: Theme.spaceXL

        AppTile {
            appId: "spotify"; appName: "Spotify"
            appIcon: "🎵"; accentColor: "#1DB954"
            appSubtitle: "Music & podcasts"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
        AppTile {
            appId: "youtube"; appName: "YouTube"
            appIcon: "▶"; accentColor: "#FF0000"
            appSubtitle: "Videos & live"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
        AppTile {
            appId: "browser"; appName: "Browser"
            appIcon: "🌐"; accentColor: Theme.accent
            appSubtitle: "Browse the web"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
        AppTile {
            appId: "cast"; appName: "Cast"
            appIcon: "📡"; accentColor: Theme.accentPurple
            appSubtitle: "Receive Miracast"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }

        AppTile {
            appId: "apps"; appName: "All Apps"
            appIcon: "▦"; accentColor: Theme.accentSoft
            appSubtitle: "Browse all"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
        AppTile {
            appId: "network"; appName: "Network"
            appIcon: "📶"; accentColor: Theme.accentSoft
            appSubtitle: "Wi-Fi settings"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
        AppTile {
            appId: "bluetooth"; appName: "Bluetooth"
            appIcon: "🔵"; accentColor: Theme.accent
            appSubtitle: "Pair devices"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
        AppTile {
            appId: "settings"; appName: "Settings"
            appIcon: "⚙"; accentColor: Theme.textSecondary
            appSubtitle: "System preferences"
            Layout.preferredWidth: 220
            Layout.preferredHeight: 280
            onLaunched: (id) => root.goTo(id)
        }
    }

    // ── Footer hint ──────────────────────────────────────────────────────
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceL
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL

        Repeater {
            model: [
                { key: "↑↓←→", label: "Navigate" },
                { key: "OK",    label: "Select" },
                { key: "⤺",     label: "Back" },
                { key: "⌂",     label: "Home" },
                { key: "⏻",     label: "Power" }
            ]
            delegate: Row {
                spacing: Theme.spaceS

                Rectangle {
                    width: 32; height: 32
                    radius: Theme.radiusS
                    color: Qt.rgba(255,255,255,0.06)
                    border.color: Qt.rgba(255,255,255,0.1)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.key
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        font.weight: Font.Bold
                    }
                }
                Text {
                    text: modelData.label
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
