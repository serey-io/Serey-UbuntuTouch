import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Horizontal chip selector (e.g. Trending / Hot / New). Set `model` to a list
 * of labels; emits selected(index) and exposes currentIndex.
 */
Flickable {
    id: root
    property var model: []
    property int currentIndex: 0
    signal selected(int index)

    implicitHeight: units.gu(5)
    contentWidth: row.width
    flickableDirection: Flickable.HorizontalFlick
    clip: true

    Row {
        id: row
        height: parent.height
        spacing: Style.spacingS
        leftPadding: Style.spacingM
        rightPadding: Style.spacingM

        Repeater {
            model: root.model
            delegate: AbstractButton {
                id: chip
                height: units.gu(4)
                width: chipLabel.implicitWidth + Style.spacingL
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                property bool active: index === root.currentIndex

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: chip.active ? Style.brand
                                       : (chip.pressed ? Style.pressed : Style.divider)
                }
                Label {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData
                    textSize: Label.Small
                    color: chip.active ? Style.textOnBrand : Style.textPrimary
                }
                onClicked: {
                    root.currentIndex = index;
                    root.selected(index);
                }
            }
        }
    }
}
