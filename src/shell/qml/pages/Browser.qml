import QtQuick
import QtQuick.Controls
import "../components"
import "../styles"
import ZAIos.Shell

Item {
    id: browserPage
    anchors.fill: parent

    Component.onCompleted: searchInput.forceActiveFocus();

    Column {
        anchors.centerIn: parent
        spacing: Theme.spaceL

        Text {
            text: "🌐"
            font.pixelSize: 80
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Browser Not Available"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeXL
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "QtWebEngine was not included in this build."
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
