import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

// Lomiri list section header: small grey caption sitting just above its rows.
// Lomiri Label has no padding properties, so the inset comes from anchors.
Item {
    property alias text: caption.text

    width: parent ? parent.width : 0
    height: units.gu(4.5)

    Label {
        id: caption
        anchors {
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: Style.spacingM; rightMargin: Style.spacingM
            bottomMargin: Style.spacingXs
        }
        font.pixelSize: Style.fontSmall
        font.family: Style.fontFor(text)
        color: Style.textSecondary
        elide: Text.ElideRight
    }
}
