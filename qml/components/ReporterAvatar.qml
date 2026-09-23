import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

// Round avatar: photo, else initial, else "?" (anonymous)
Item {
    id: root
    property string name: ""
    property string source: ""
    property real size: units.gu(4)

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.name ? Style.avatarTint(root.name) : Style.iconBackground
        visible: root.source === ""
        Label {
            anchors.centerIn: parent
            text: root.name ? root.name.charAt(0).toUpperCase() : "?"
            font.pixelSize: root.size * 0.42
            font.bold: true
            color: root.name ? Style.brand : Style.textSecondary
        }
    }

    CircleImage {
        anchors.fill: parent
        visible: root.source !== ""
        source: root.source
        decode: root.size * 2
    }
}
