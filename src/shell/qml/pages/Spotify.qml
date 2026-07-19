/*
 * Spotify.qml — Spotify music app.
 *
 * Layout:
 *   - Search bar (top)
 *   - "Now Playing" panel (left) — album art, title, artist, controls
 *   - Search results grid (right) — track tiles with album art
 * Search via SpotifyManager → backend service queries Spotify Web API.
 * Play via Spotube-style (YouTube-backed, no premium needed).
 */
import QtQuick
import "../components"
import "../styles"
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: spotifyPage
    anchors.fill: parent
    property var currentTrack: null
    Component.onCompleted: {
        searchInput.forceActiveFocus();
    }
    // ── Search bar (top) ─────────────────────────────────────────────────
    SearchBar {
        id: searchInput
        anchors.top: parent.top
        anchors.topMargin: 88
        anchors.horizontalCenter: parent.horizontalCenter
        placeholder: "Search Spotify for songs, artists, albums..."
        onSearchSubmitted: (q) => Spotify.search(q)
    // ── Main content ─────────────────────────────────────────────────────
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
            Layout.preferredWidth: 360
            Layout.fillHeight: true
            radius: Theme.radiusXL
            glow: Spotify.playing
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceL
                spacing: Theme.spaceM
                Text {
                    text: "NOW PLAYING"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXS
                    font.weight: Font.Bold
                    letterSpacing: 2
                }
                // Album art
                Rectangle {
                    width: 280; height: 280
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.radiusL
                    color: Theme.bgLight
                    border.color: Qt.rgba(255,255,255,0.1)
                    border.width: 1
                    // Animated equalizer when playing
                    Item {
                        anchors.centerIn: parent
                        visible: Spotify.playing
                        width: 80; height: 60
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: 5
                                Rectangle {
                                    width: 8; height: 8 + Math.random() * 50
                                    radius: 4
                                    color: Theme.accent
                                    anchors.bottom: parent.bottom
                                    SequentialAnimation on height {
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 8 + Math.random() * 50; duration: 300 + Math.random() * 400 }
                                        NumberAnimation { to: 10; duration: 300 + Math.random() * 400 }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        text: "🎵"
                        font.pixelSize: 80
                        visible: !Spotify.playing
                        opacity: 0.4
                    text: Spotify.title || "No track selected"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeL
                    width: parent.width
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    text: Spotify.backend === "librespot" ? "Spotify Premium" : "Spotube (free)"
                    color: Spotify.backend === "librespot" ? Theme.success : Theme.accentSoft
                    font.pixelSize: Theme.fontSizeS
                // Progress bar
                Item {
                    height: 32
                    Column {
                        anchors.fill: parent
                        spacing: 4
                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(255,255,255,0.1)
                            Rectangle {
                                width: parent.width * (Spotify.duration > 0 ? (Spotify.pos / Spotify.duration) : 0)
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                                Behavior on width { NumberAnimation { duration: 1000 } }
                            Text {
                                text: formatTime(Spotify.pos)
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSizeXS
                                width: parent.width / 2
                                horizontalAlignment: Text.AlignLeft
                                text: formatTime(Spotify.duration)
                                horizontalAlignment: Text.AlignRight
                // Playback controls
                Row {
                    spacing: Theme.spaceM
                    FocusButton {
                        text: "⏮"; width: 56; height: 56
                        cornerRadius: 28
                        onClicked: {}  // prev track (not implemented)
                        text: Spotify.playing ? "⏸" : "▶"
                        width: 72; height: 72
                        cornerRadius: 36
                        bgColor: Theme.accent
                        bgColorFocused: Theme.accentSoft
                        textColor: Theme.bgDeep
                        textColorFocused: Theme.bgDeep
                        onClicked: Spotify.playing ? Spotify.pause() : Spotify.resume()
                        text: "⏭"; width: 56; height: 56
                        onClicked: {}
            }
        }
        // ── Right: Search results ────────────────────────────────────────
            Layout.fillWidth: true
                spacing: Theme.spaceS
                    text: Spotify.results.length > 0 ? "SEARCH RESULTS" : "POPULAR SEARCHES"
                    color: Theme.textSecondary
                ScrollView {
                    height: parent.height - 32
                    clip: true
                    ListView {
                        id: resultsList
                        model: Spotify.results
                        spacing: Theme.spaceS
                        delegate: FocusButton {
                            width: resultsList.width
                            height: 72
                            cornerRadius: Theme.radiusM
                            text: ""
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spaceM
                                anchors.rightMargin: Theme.spaceM
                                spacing: Theme.spaceM
                                // Album art thumbnail
                                    width: 56; height: 56
                                    radius: Theme.radiusS
                                    color: Theme.bgLight
                                    anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.art || ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.art !== undefined && modelData.art.length > 0
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🎵"
                                        font.pixelSize: 24
                                        opacity: 0.4
                                        visible: modelData.art === undefined || modelData.art.length === 0
                                Column {
                                    width: parent.width - 56 - Theme.spaceM - 80
                                    spacing: 2
                                        text: modelData.title || "Unknown"
                                        color: parent.parent.activeFocus ? Theme.accent : Theme.textPrimary
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Medium
                                        font.pixelSize: Theme.fontSizeM
                                        elide: Text.ElideRight
                                        width: parent.width
                                        text: modelData.artist || ""
                                        color: Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeS
                                Text {
                                    text: formatTime(modelData.duration || 0)
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeS
                            onClicked: {
                                Spotify.play(modelData.id, modelData.title,
                                             modelData.artist, modelData.duration);
    function formatTime(secs) {
        if (!secs || secs <= 0) return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
}
