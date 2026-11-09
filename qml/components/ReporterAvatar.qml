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
        // until photo loads
        visible: !photo.loaded
        Label {
            anchors.centerIn: parent
            text: root.name ? root.name.charAt(0).toUpperCase() : "?"
            font.pixelSize: root.size * 0.42
            font.bold: true
            color: root.name ? Style.brand : Style.textSecondary
        }
    }

    CircleImage {
        id: photo
        anchors.fill: parent
        visible: loaded
        source: root.source
        decode: root.size * 2
    }
}
