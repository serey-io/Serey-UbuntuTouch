import QtQuick 2.7
import Lomiri.Components 1.3

// Centered spinner shown while a list/detail is loading.
Item {
    id: root
    property string message: ""

    Column {
        anchors.centerIn: parent
        spacing: units.gu(2)

        ActivityIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: root.visible
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.message
            textSize: Label.Small
            visible: text.length > 0
        }
    }
}
