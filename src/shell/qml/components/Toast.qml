import QtQuick
import "../styles"
import ZAIos.Shell

Rectangle {
    id: toast
    width: 380
    height: 64
    radius: Theme.radiusM
    color: Qt.rgba(0.1, 0.15, 0.3, 0.9)
    border.color: Qt.rgba(255, 255, 255, 0.1)
    border.width: 1

    property string title: ""
    property string body: ""
    property string severity: "info"
    signal dismissed()

    readonly property color accentColor: {
        if (severity === "success") return Theme.success;
        if (severity === "warning") return Theme.warning;
        if (severity === "error")   return Theme.error;
        return Theme.accent;
    }

    Component.onCompleted: {
        toast.x = -toast.width;
        enterAnim.start();
        autoDismissTimer.start();
    }

    NumberAnimation on x {
        id: enterAnim
        from: -toast.width
        to: 0
        duration: Theme.durationNormal
        easing.type: Theme.easingSpring
        running: false
    }

    Timer {
        id: autoDismissTimer
        interval: 4000
        onTriggered: dismiss()
    }

    function dismiss() {
        exitAnim.start();
    }

    SequentialAnimation {
        id: exitAnim
        NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Theme.durationNormal }
        NumberAnimation { target: toast; property: "height"; to: 0; duration: Theme.durationFast }
        ScriptAction { script: toast.dismissed() }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spaceM
        spacing: Theme.spaceM

        Rectangle {
            width: 6
            height: parent.height
            radius: 3
            color: toast.accentColor
        }

        Column {
            width: parent.width - 18
            height: parent.height
            spacing: 2

            Text {
                text: toast.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeM
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: toast.body
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                elide: Text.ElideRight
                width: parent.width
                visible: text.length > 0
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: dismiss()
    }
}
