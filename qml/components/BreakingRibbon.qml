import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

// Breaking news banner: notched left end, fold under right
Item {
    id: root

    property real bannerHeight: units.gu(3)
    property int fontSize: Style.fontXSmall
    readonly property real notch: bannerHeight / 3
    // Fold depth; host may let this hang past an edge
    readonly property real fold: notch / 2

    width: label.width + notch + Style.spacingM
    height: bannerHeight

    Canvas {
        id: shape
        width: parent.width
        height: root.bannerHeight + root.fold
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            var w = width, h = root.bannerHeight, n = root.notch, f = root.fold;
            ctx.reset();
            ctx.fillStyle = Qt.darker(Style.accentRed, 1.6);
            ctx.beginPath();
            ctx.moveTo(w - f, h); ctx.lineTo(w, h); ctx.lineTo(w - f, h + f);
            ctx.closePath(); ctx.fill();
            ctx.fillStyle = Style.accentRed;
            ctx.beginPath();
            ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h);
            ctx.lineTo(0, h); ctx.lineTo(n, h / 2);
            ctx.closePath(); ctx.fill();
        }
    }

    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.notch / 2
        text: Lang.tr("Breaking news").toUpperCase()
        font.pixelSize: root.fontSize
        font.weight: Font.Black
        color: Style.textOnBrand
    }
}
