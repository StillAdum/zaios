/* ZAIos Calamares slideshow — shown during install */
import QtQuick 2.15

Rectangle {
    color: "#050816"
    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        spacing: 32

        Text {
            text: "Installing ZAIos..."
            color: "#FFFFFF"
            font.family: "Inter"
            font.weight: Font.Bold
            font.pixelSize: 36
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Your TV OS is being set up. This will take a few minutes."
            color: "#B0BBD8"
            font.family: "Inter"
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Spinner
        Rectangle {
            width: 64; height: 64
            radius: 32
            color: "transparent"
            border.color: "#00E5FF"
            border.width: 4
            anchors.horizontalCenter: parent.horizontalCenter

            RotationAnimator on rotation {
                from: 0; to: 360
                duration: 1500
                loops: Animation.Infinite
                running: true
            }

            // Mask to make it look like a spinner
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height / 2
                color: "#050816"
            }
        }
    }
}
