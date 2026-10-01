import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

AbstractButton {
    id: root

    property string text: ""
    property bool busy: false
    property color accent: Style.brand
    property color dotColor: "transparent"   // status dot in the side segment; transparent = none
    property string iconName: ""             // icon in the side segment (wins over the dot)
    readonly property bool _hasCell: iconName !== "" || dotColor.a > 0

    width: parent ? parent.width : units.gu(40)
    height: units.gu(5)
    enabled: !busy
    // Content-fit width
    implicitWidth: content.width + iconCell.width + units.gu(3)

    Rectangle {
        anchors.fill: parent
        radius: Style.cardRadius
        color: root.pressed ? Style.iconBackground : "transparent"
        border.width: units.dp(1.5)
        border.color: root.accent
        Behavior on color { ColorAnimation { duration: 120 } }

        // With an icon or dot the button splits: label centred on the left, the marker in
        // its own square segment on the right behind a divider (spinner there while busy).
        Item {
            id: iconCell
            visible: root._hasCell
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: visible ? height : 0
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: units.dp(1.5)
                color: root.accent
            }
            ActivityIndicator {
                anchors.centerIn: parent
                running: root.busy && visible
                visible: root.busy
                implicitWidth: units.gu(2.5)
                implicitHeight: units.gu(2.5)
            }
            Rectangle {
                anchors.centerIn: parent
                visible: !root.busy && root.iconName === ""
                width: units.gu(1.25); height: width; radius: width / 2
                color: root.dotColor
            }
            Icon {
                anchors.centerIn: parent
                visible: !root.busy && root.iconName !== ""
                name: root.iconName
                width: units.gu(2.5); height: width
                color: root.accent
            }
        }

        Row {
            id: content
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -iconCell.width / 2
            spacing: Style.spacingS

            ActivityIndicator {
                anchors.verticalCenter: parent.verticalCenter
                running: root.busy && visible
                visible: root.busy && !root._hasCell
                implicitWidth: units.gu(2.5)
                implicitHeight: units.gu(2.5)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.pixelSize: Style.fontMedium
                font.weight: Font.DemiBold
                font.family: Style.fontFor(text)
                color: root.accent
            }
        }
    }
}
