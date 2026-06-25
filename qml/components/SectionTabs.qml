import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Segmented tab strip (e.g. Trending / Hot / New) in the serey-ubutu style:
 * left-aligned labels with the active one tinted brand and underlined by a
 * short pill. Set `model` to a list of labels; emits selected(index) and
 * exposes currentIndex.
 */
Item {
    id: root
    property var model: []
    property int currentIndex: 0
    signal selected(int index)

    implicitHeight: units.gu(5.5)

    Row {
        id: row
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: Style.spacingM }
        height: parent.height
        spacing: Style.spacingL

        Repeater {
            model: root.model
            delegate: AbstractButton {
                id: tab
                height: row.height
                width: tabLabel.implicitWidth
                property bool active: index === root.currentIndex
                onClicked: { root.currentIndex = index; root.selected(index); }

                Label {
                    id: tabLabel
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                    text: modelData
                    font.pixelSize: Style.fontMedium
                    font.weight: tab.active ? Font.DemiBold : Font.Normal
                    color: tab.active ? Style.brand : Style.textSecondary
                }

                // Active underline
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    width: tabLabel.implicitWidth
                    height: units.dp(3)
                    radius: units.dp(1.5)
                    color: Style.brand
                    visible: tab.active
                }
            }
        }
    }

    // Baseline hairline
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
    }
}
