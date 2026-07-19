/*
 * SetupWizard.qml — First-boot setup flow.
 *
 * Multi-step wizard:
 *   1. Welcome
 *   2. Language picker
 *   3. WiFi connect
 *   4. Bluetooth pair (optional)
 *   5. Spotify account (optional — Spotube works without)
 *   6. Hostname
 *   7. Timezone
 *   8. Complete
 * D-pad navigates within each step; Back/Next buttons at the bottom.
 */
import QtQuick
import "../components"
import "../styles"
import QtQuick.Layouts
import ZAIos.Shell

Item {
    id: wizardRoot
    anchors.fill: parent
    // ── Header: progress dots ────────────────────────────────────────────
    Row {
        id: progressDots
        anchors.top: parent.top
        anchors.topMargin: 80
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceS
        Repeater {
            model: 8
            Rectangle {
                width: 12; height: 12
                radius: 6
                color: index <= Settings.setupComplete ? Theme.accent : Qt.rgba(255,255,255,0.1)
                opacity: index === 0 ? 1.0 : 0.6
                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                Behavior on scale { NumberAnimation { duration: Theme.durationNormal } }
                scale: index === 0 ? 1.2 : 1.0
            }
        }
    }
    // ── Title + description ──────────────────────────────────────────────
    Column {
        id: header
        anchors.top: progressDots.bottom
        anchors.topMargin: Theme.spaceXXL
        Text {
            text: "Welcome to ZAIos"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXXXL
            anchors.horizontalCenter: parent.horizontalCenter
            NumberAnimation on opacity { from: 0; to: 1; duration: Theme.durationSlow }
            NumberAnimation on y { from: 30; to: 0; duration: Theme.durationSlow; easing.type: Theme.easingSpring }
            text: "Let's set up your TV OS in just a few steps."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeL
            NumberAnimation on opacity { from: 0; to: 1; duration: Theme.durationSlowest }
    // ── Main content area (changes per step) ─────────────────────────────
    GlassCard {
        id: contentCard
        anchors.top: header.bottom
        width: 800
        height: 320
        radius: Theme.radiusXL
        glow: true
        // Welcome content
        Column {
            anchors.centerIn: parent
            spacing: Theme.spaceL
            visible: true
            Text {
                text: "📺"
                font.pixelSize: 100
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ZAIos is a custom TV operating system."
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeL
                text: "You'll be watching, listening, and casting in minutes."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeM
    // ── Bottom navigation buttons ────────────────────────────────────────
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        spacing: Theme.spaceM
        FocusButton {
            text: "Skip Setup"
            width: 160; height: 56
            cornerRadius: Theme.radiusPill
            bgColor: Qt.rgba(255,255,255,0.05)
            onClicked: Settings.setupComplete = true
            text: "Get Started  →"
            width: 220; height: 56
            focus: true
}
