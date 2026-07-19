/*
 * YouTube.qml — YouTube video app.
 *
 * Layout:
 *   - Search bar (top)
 *   - Grid of video thumbnails (right) — uses Invidious API for search
 *   - Player area (left) — embedded mpv window (via QQuickItem)
 *
 * Playback is via mpv subprocess (full screen video). The Qt shell talks
 * to mpv via its IPC socket for play/pause/seek.
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell
import "../components"
import "../styles"

Item {
    id: ytPage
    anchors.fill: parent

    Component.onCompleted: searchInput.forceActiveFocus();

    // ── Search bar ───────────────────────────────────────────────────────
    SearchBar {
        id: searchInput
        anchors.top: parent.top
        anchors.topMargin: 88
        anchors.horizontalCenter: parent.horizontalCenter
        placeholder: "Search YouTube..."
        onSearchSubmitted: (q) => YouTube.search(q)
    }

    RowLayout {
        anchors.top: searchInput.bottom
        anchors.topMargin: Theme.spaceL
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXL
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceXL
        spacing: Theme.spaceL

        // ── Left: Now Playing ────────────────────────────────────────────
        GlassCard {
            Layout.preferredWidth: 580
            Layout.fillHeight: true
            radius: Theme.radiusXL
            glow: YouTube.playing

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceL
                spacing: Theme.spaceM

                Text {
                    text: "NOW PLAYING"
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXS
                    font.weight: Font.Bold
                    letterSpacing: 2
                    visible: YouTube.playing
                }

                // Video preview placeholder
                Rectangle {
                    width: parent.width
                    height: width * 9/16
                    radius: Theme.radiusL
                    color: "#000000"
                    border.color: Qt.rgba(255,255,255,0.1)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: YouTube.playing ? "▶" : "▶"
                        color: YouTube.playing ? Theme.error : Theme.textMuted
                        font.pixelSize: 80
                    }

                    // Video info overlay at bottom
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 60
                        color: Qt.rgba(0,0,0,0.7)
                        radius: Theme.radiusS

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: YouTube.title || "No video selected"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeM
                                elide: Text.ElideRight
                                width: parent.width - 20
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // Playback controls
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spaceM

                    FocusButton {
                        text: "⏮"; width: 56; height: 56; cornerRadius: 28
                        onClicked: YouTube.seek(Math.max(0, YouTube.pos - 10))
                    }
                    FocusButton {
                        text: YouTube.playing ? "⏸" : "▶"
                        width: 72; height: 72; cornerRadius: 36
                        bgColor: Theme.error
                        bgColorFocused: "#FF5566"
                        textColor: "white"
                        textColorFocused: "white"
                        onClicked: YouTube.playing ? YouTube.pause() : YouTube.resume()
                    }
                    FocusButton {
                        text: "⏭"; width: 56; height: 56; cornerRadius: 28
                        onClicked: YouTube.seek(YouTube.pos + 10)
                    }
                    FocusButton {
                        text: "⏹"; width: 56; height: 56; cornerRadius: 28
                        bgColor: Qt.rgba(255,61,90,0.2)
                        onClicked: YouTube.stop()
                    }
                }

                // Progress bar
                Item {
                    width: parent.width
                    height: 24
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(255,255,255,0.1)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: parent.width * (YouTube.duration > 0 ? YouTube.pos / YouTube.duration : 0)
                            height: parent.height
                            radius: 2
                            color: Theme.error
                        }
                    }
                }
            }
        }

        // ── Right: Search results ────────────────────────────────────────
        GlassCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusXL

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceL
                spacing: Theme.spaceS

                Text {
                    text: YouTube.results.length > 0 ? "RESULTS" : "TRENDING"
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

                    GridView {
                        id: grid
                        model: YouTube.results
                        cellWidth: (width - Theme.spaceS) / 2
                        cellHeight: 160
                        spacing: Theme.spaceS

                        delegate: FocusButton {
                            width: grid.cellWidth - 4
                            height: grid.cellHeight - 4
                            cornerRadius: Theme.radiusM
                            text: ""

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spaceS
                                spacing: Theme.spaceS

                                // Thumbnail
                                Rectangle {
                                    width: 128; height: 72
                                    radius: Theme.radiusS
                                    color: Theme.bgLight
                                    anchors.verticalCenter: parent.verticalCenter
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.thumbnail || ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.thumbnail !== undefined
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"
                                        color: Theme.textMuted
                                        font.pixelSize: 24
                                        visible: modelData.thumbnail === undefined
                                    }

                                    // Duration overlay
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 2
                                        radius: 2
                                        color: Qt.rgba(0,0,0,0.8)
                                        width: durationLabel.implicitWidth + 8
                                        height: durationLabel.implicitHeight + 2

                                        Text {
                                            id: durationLabel
                                            anchors.centerIn: parent
                                            text: formatTime(modelData.lengthSeconds || 0)
                                            color: "white"
                                            font.pixelSize: Theme.fontSizeXS
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width - 128 - Theme.spaceS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.title || "Untitled"
                                        color: parent.parent.activeFocus ? Theme.error : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Medium
                                        font.pixelSize: Theme.fontSizeS
                                        elide: Text.ElideRight
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        maximumLineCount: 2
                                        width: parent.width
                                    }
                                    Text {
                                        text: modelData.author || ""
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXS
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }

                            onClicked: YouTube.play(modelData.videoId, modelData.title)
                        }
                    }
                }
            }
        }
    }

    function formatTime(secs) {
        if (!secs || secs <= 0) return "0:00";
        var h = Math.floor(secs / 3600);
        var m = Math.floor((secs % 3600) / 60);
        var s = Math.floor(secs % 60);
        if (h > 0) return h + ":" + (m<10?"0":"") + m + ":" + (s<10?"0":"") + s;
        return m + ":" + (s<10?"0":"") + s;
    }
}
