import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Bottom-sheet community/source selector. Lists the static Config.sources
 * (Global / regional). Selecting a row sets Config.sourceIndex, which the feeds
 * and videos already react to. Mounted once as a top-level overlay; toggle via
 * open() / close().
 */
Item {
    id: picker

    anchors.fill: parent
    visible: false
    z: 1500

    function open() { picker.visible = true; }
    function close() { picker.visible = false; }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        MouseArea { anchors.fill: parent; onClicked: picker.close() }
    }

    // Sheet
    Rectangle {
        id: sheet
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: header.height + list.contentHeight + units.gu(4)
        radius: units.dp(16)
        color: Style.surface

        // Grabber
        Rectangle {
            anchors { top: parent.top; topMargin: Style.spacingS; horizontalCenter: parent.horizontalCenter }
            width: units.gu(4.5)
            height: units.dp(4)
            radius: units.dp(2)
            color: Style.lightGray
        }

        Column {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Style.spacingL }

            Item { width: 1; height: Style.spacingS }
            Row {
                anchors { left: parent.left; right: parent.right; leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                Label {
                    width: parent.width - units.gu(4)
                    text: i18n.tr("Choose community")
                    font.pixelSize: units.dp(17)
                    font.weight: Font.DemiBold
                    color: Style.textTitle
                    anchors.verticalCenter: parent.verticalCenter
                }
                AbstractButton {
                    width: units.gu(3.5); height: units.gu(3.5)
                    onClicked: picker.close()
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5); height: width
                        name: "close"; color: Style.textTitle
                    }
                }
            }
            Item { width: 1; height: Style.spacingS }
        }

        ListView {
            id: list
            anchors { top: header.bottom; left: parent.left; right: parent.right }
            height: contentHeight
            interactive: false
            model: Config.sources

            delegate: AbstractButton {
                width: list.width
                height: units.gu(6.5)
                onClicked: { Config.sourceIndex = index; picker.close(); }

                Row {
                    anchors { fill: parent; leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                    spacing: Style.spacingM

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(5); height: width
                        radius: width / 2
                        color: index === Config.sourceIndex ? Style.brand : Style.iconBackground
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.5); height: width
                            name: "language-chooser"
                            color: index === Config.sourceIndex ? Style.textOnBrand : Style.textSecondary
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        font.pixelSize: Style.fontMedium
                        font.weight: index === Config.sourceIndex ? Font.DemiBold : Font.Medium
                        color: index === Config.sourceIndex ? Style.brand : Style.textPrimary
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: units.gu(8) }
                    height: units.dp(1)
                    color: Style.divider
                    visible: index < Config.sources.length - 1
                }
            }
        }
    }
}
