/*
 * Apps.qml — All-apps launcher.
 *
 * Shows a grid of all installed apps (built-ins + .desktop files from
 * /usr/share/applications). Click to launch.
 */
import QtQuick
import QtQuick.Layouts
import ZAIos.Shell
import "../components"
import "../styles"

Item {
    id: appsPage
    anchors.fill: parent

    Component.onCompleted: if (grid.children.length > 0) grid.children[0].forceActiveFocus();

    Text {
        id: header
        anchors.top: parent.top
        anchors.topMargin: 100
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        text: "All Apps"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.weight: Font.Bold
        font.pixelSize: Theme.fontSizeXXL
    }

    ScrollView {
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXL
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXXL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXXL
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceXXL
        clip: true

        GridLayout {
            id: grid
            columns: 5
            rowSpacing: Theme.spaceL
            columnSpacing: Theme.spaceL
            width: parent.width

            Repeater {
                model: Apps.apps
                delegate: AppTile {
                    appId: modelData.id
                    appName: modelData.name
                    appIcon: modelData.icon || "📱"
                    accentColor: Theme.accent
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 240
                    onLaunched: (id) => {
                        if (["spotify","youtube","browser","cast","settings","network","bluetooth","about","apps"].indexOf(id) >= 0) {
                            root.goTo(id);
                        } else {
                            Apps.launch(id);
                        }
                    }
                }
            }
        }
    }
}
