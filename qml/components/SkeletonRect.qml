import QtQuick 2.7
import "../Theme"

/*
 * A loading placeholder block with a left-to-right shimmer sweep. Building block
 * for skeleton screens (feed/video lists) shown while content loads.
 */
Rectangle {
    id: skeleton

    property bool loading: true

    color: Style.skeleton
    visible: loading
    clip: true
    radius: Style.durationBadgeRadius

    Rectangle {
        id: shimmer
        width: parent.width * 0.4
        height: parent.height
        color: Qt.rgba(1, 1, 1, 0.4)
        visible: loading

        SequentialAnimation on x {
            running: loading
            loops: Animation.Infinite
            NumberAnimation {
                from: -shimmer.width
                to: skeleton.width
                duration: 1200
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 400 }
        }
    }
}
