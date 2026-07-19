/*
 * ClockWidget.qml — Centered clock + date in the top bar.
 *
 * Uses the system timezone. Updates every second.
 */
import QtQuick
import ZAIos.Shell
import "../styles"

Item {
    width: 200
    height: 36

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            id: clockText
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeL
            anchors.horizontalCenter: parent.horizontalCenter

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    var d = new Date();
                    var h = d.getHours().toString().padStart(2, "0");
                    var m = d.getMinutes().toString().padStart(2, "0");
                    clockText.text = h + ":" + m;
                }
                Component.onCompleted: triggered()
            }
        }

        Text {
            id: dateText
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXS
            anchors.horizontalCenter: parent.horizontalCenter

            Timer {
                interval: 60000
                running: true
                repeat: true
                onTriggered: {
                    var d = new Date();
                    var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
                    dateText.text = days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
                }
                Component.onCompleted: triggered()
            }
        }
    }
}
