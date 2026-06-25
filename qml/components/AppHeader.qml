import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Global top navbar: a tappable community-selector pill on the left and the
 * centered Serey logo. The pill shows the active source (Config.communityName)
 * and opens the CommunityPicker when tapped. An optional trailing action slot
 * (e.g. refresh) sits on the right.
 */
Rectangle {
    id: appHeader

    property string communityName: Config.communityName
    default property alias trailing: trailingSlot.data

    signal communityButtonClicked()

    height: units.gu(6)
    color: Style.navigationBg

    // Left: community selector pill
    Rectangle {
        id: pill
        anchors {
            left: parent.left
            leftMargin: Style.spacingM
            verticalCenter: parent.verticalCenter
        }
        height: units.gu(4.25)
        width: communityRow.width + Style.spacingM
        radius: height / 2
        color: Style.iconBackground

        Row {
            id: communityRow
            anchors {
                left: parent.left
                leftMargin: Style.spacingS
                verticalCenter: parent.verticalCenter
            }
            spacing: Style.spacingXs

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(2.6); height: width
                radius: width / 2
                color: "transparent"
                clip: true
                Image {
                    id: pillIcon
                    anchors.fill: parent
                    source: Config.communityIcon(Config.communityDns)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source != "" && status === Image.Ready
                }
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.5); height: width
                    name: "language-chooser"
                    color: Style.textPrimary
                    visible: !pillIcon.visible
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: appHeader.communityName.length > 12
                      ? appHeader.communityName.substring(0, 12)
                      : appHeader.communityName
                font.pixelSize: Style.fontRegular
                font.weight: Font.Medium
                color: Style.textPrimary
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "▾"
                font.pixelSize: Style.fontRegular
                color: Style.textPrimary
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: appHeader.communityButtonClicked()
        }
    }

    // Center: Serey logo
    Image {
        anchors.centerIn: parent
        width: units.gu(5.5)
        height: width
        source: Qt.resolvedUrl("../../assets/serey-logo.png")
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    // Right: trailing action slot (e.g. refresh)
    Item {
        id: trailingSlot
        anchors {
            right: parent.right
            rightMargin: Style.spacingM
            verticalCenter: parent.verticalCenter
        }
        width: childrenRect.width
        height: parent.height
    }

    // Bottom hairline
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
    }
}
