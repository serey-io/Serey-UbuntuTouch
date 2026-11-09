import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

// transport button
AbstractButton {
    id: root

    property string icon: ""
    property bool big: false
    // small blue circle
    property bool accent: false
    readonly property bool filled: big || accent
    property bool busy: false
    // seconds label under seek icons
    property string caption: ""

    readonly property color ink: root.filled ? Style.textOnBrand : Style.textPrimary

    width: big ? units.gu(8) : units.gu(5)
    height: width
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.filled ? (root.pressed ? Style.brandDark : Style.brand) : (root.pressed ? Style.pressed : "transparent")
    }
    Icon {
        id: glyph
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.caption ? -units.gu(0.6) : 0
        // big keeps its icon, dims while loading
        visible: !root.busy || root.filled
        opacity: root.busy ? 0.4 : 1
        width: root.big ? units.gu(3.5) : units.gu(2.75); height: width
        name: root.icon
        color: root.ink
    }
    Label {
        anchors { horizontalCenter: parent.horizontalCenter; top: glyph.bottom }
        visible: root.caption.length > 0
        text: root.caption
        font.pixelSize: Style.fontXSmall
        font.weight: Font.DemiBold
        color: root.ink
    }
    ActivityIndicator {
        anchors.centerIn: parent
        running: root.busy && !root.filled
        visible: running
    }
    KeyTapArea { onActivated: root.clicked() }
}
