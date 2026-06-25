import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Loading placeholder shown while a list/detail is fetching. Renders a few
 * shimmer skeleton "cards" (serey-ubutu style) rather than a bare spinner.
 */
Item {
    id: root
    property string message: ""

    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 0

        Repeater {
            model: 3
            delegate: Column {
                width: root.width
                spacing: Style.spacingS
                topPadding: Style.spacingM

                // Header: avatar + two lines
                Row {
                    x: Style.spacingM
                    spacing: Style.spacingS
                    SkeletonRect { width: units.gu(4.25); height: width; radius: width / 2 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.spacingXs
                        SkeletonRect { width: units.gu(18); height: units.gu(1.5) }
                        SkeletonRect { width: units.gu(10); height: units.gu(1.2) }
                    }
                }

                // Cover image block
                SkeletonRect {
                    x: Style.spacingM
                    width: root.width - Style.spacingM * 2
                    height: (root.width - Style.spacingM * 2) * 0.56
                    radius: Style.thumbRadius
                }

                // Action line
                SkeletonRect {
                    x: Style.spacingM
                    width: units.gu(22); height: units.gu(2)
                }

                Item { width: 1; height: Style.spacingS }
                Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }
            }
        }
    }
}
