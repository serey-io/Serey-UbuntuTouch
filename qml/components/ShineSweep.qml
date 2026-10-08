import QtQuick 2.7
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3

// Looped shine strip, clipped to `mask`
Item {
    id: root

    // Same size as this item
    property Item mask: null
    property int sweepDuration: 1500
    property int pauseDuration: 2200
    property real progress: 0

    layer.enabled: visible && !!mask
    layer.effect: OpacityMask { maskSource: root.mask }

    Rectangle {
        id: strip
        width: units.gu(1.4)
        height: root.height * 2
        y: -root.height / 2
        x: -width * 2 + (root.width + width * 3) * root.progress
        rotation: 20
        color: Qt.rgba(1, 1, 1, 0.35)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.4; height: parent.height
            color: Qt.rgba(1, 1, 1, 0.35)
        }
    }

    SequentialAnimation {
        running: root.visible && !!root.mask
        loops: Animation.Infinite
        NumberAnimation {
            target: root; property: "progress"
            from: 0; to: 1
            duration: root.sweepDuration; easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: root.pauseDuration }
    }
}
