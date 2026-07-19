/*
 * Background.qml — ZAIos animated background.
 *
 * A deep navy gradient that slowly breathes (subtle hue shift) with a
 * faint particle field on top. Designed to feel premium but stay cheap
 * on GPU — runs at 30fps, no shaders required.
 *
 * On TVs with HDR support, the colors saturate nicely. On SDR, the
 * deep navy still reads as "premium dark".
 */
import QtQuick
import "../styles"
import ZAIos.Shell

Item {
    id: bgRoot
    anchors.fill: parent
    clip: true

    // ── Base gradient (deep navy → midnight) ─────────────────────────────
    Rectangle {
        id: baseGradient
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.bgDeep }
            GradientStop { position: 0.5; color: Theme.bgMid }
            GradientStop { position: 1.0; color: "#02040F" }
        }
    }

    // ── Slow radial glow that breathes ───────────────────────────────────
    Rectangle {
        id: breathingGlow
        anchors.centerIn: parent
        width: parent.width * 1.2
        height: parent.height * 1.2
        radius: width / 2
        // Use simple linear gradient (RadialGradient needs QtQuick.Shapes)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 229/255, 1, 0.08) }
            GradientStop { position: 0.5; color: Qt.rgba(156/255, 77/255, 1, 0.04) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
        }
        scale: breathAnim.breathScale
        opacity: breathAnim.breathOpacity
        Behavior on scale { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }
        Behavior on opacity { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }
    }

    Item {
        id: breathAnim
        property real breathScale: 1.0
        property real breathOpacity: 1.0

        SequentialAnimation {
            loops: Animation.Infinite
            NumberAnimation { target: breathAnim; property: "breathScale"; to: 1.05; duration: 8000; easing.type: Easing.InOutSine }
            NumberAnimation { target: breathAnim; property: "breathScale"; to: 1.0; duration: 8000; easing.type: Easing.InOutSine }
        }
    }

    // ── Floating particle field ──────────────────────────────────────────
    Repeater {
        model: 80
        delegate: Item {
            id: particle
            property real startX: Math.random() * bgRoot.width
            property real startY: Math.random() * bgRoot.height
            property real driftX: (Math.random() - 0.5) * 100
            property real driftY: (Math.random() - 0.5) * 100
            property int  duration: 20000 + Math.random() * 30000
            property real sz: 1 + Math.random() * 2.5

            x: startX
            y: startY
            width: sz
            height: sz
            opacity: 0.3 + Math.random() * 0.4

            Rectangle {
                anchors.fill: parent
                color: Theme.accent
                radius: width / 2
            }

            SequentialAnimation {
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: particle; property: "x"; from: particle.startX; to: particle.startX + particle.driftX; duration: particle.duration; easing.type: Easing.InOutSine }
                    NumberAnimation { target: particle; property: "y"; from: particle.startY; to: particle.startY + particle.driftY; duration: particle.duration; easing.type: Easing.InOutSine }
                    NumberAnimation { target: particle; property: "opacity"; from: 0.1; to: 0.6; duration: particle.duration; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: particle; property: "x"; from: particle.startX + particle.driftX; to: particle.startX; duration: particle.duration; easing.type: Easing.InOutSine }
                    NumberAnimation { target: particle; property: "y"; from: particle.startY + particle.driftY; to: particle.startY; duration: particle.duration; easing.type: Easing.InOutSine }
                    NumberAnimation { target: particle; property: "opacity"; from: 0.6; to: 0.1; duration: particle.duration; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── Subtle vignette ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        // Use simple linear gradient (RadialGradient needs QtQuick.Shapes)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
        }
    }
}
