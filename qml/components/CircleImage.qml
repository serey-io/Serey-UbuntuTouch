import QtQuick 2.7
import QtGraphicalEffects 1.0

/*
 * An image clipped to a circle. Qt's `clip: true` only clips to the bounding
 * rectangle (it ignores `radius`), so a rectangular source like a flag shows
 * square corners. OpacityMask masks the image to a circular shape instead.
 *
 * `loaded` is true once a real image has decoded — callers show a fallback
 * (e.g. a globe icon) while it's false.
 */
Item {
    id: root

    property url source: ""
    readonly property bool loaded: img.status === Image.Ready && String(source) !== ""

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: mask }
    }
}
