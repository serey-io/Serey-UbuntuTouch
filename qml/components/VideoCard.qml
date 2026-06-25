import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"

/*
 * Video row (serey-ubutu VideoCard style): 16:9 rounded thumbnail with a
 * bottom-right duration badge, then an avatar + 2-line title + "author · N
 * comments" meta. Emits clicked(). Expects a view-model from Mappers.toVideo().
 *
 * Outer stack is a plain Column (not ColumnLayout): sizing the card from an
 * anchored Layout's implicitHeight produces a binding loop.
 */
AbstractButton {
    id: root
    property var video: ({})
    // Guard: the delegate may rebind `video` to undefined during model churn.
    readonly property var v: video ? video : ({})

    width: parent ? parent.width : units.gu(40)
    implicitHeight: column.height + Style.spacingM * 2
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: root.pressed ? Style.pressed : "transparent"
    }

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.spacingM
        }
        spacing: Style.spacingS

        // Thumbnail 16:9
        Item {
            width: parent.width
            height: width * 9 / 16

            Rectangle {
                anchors.fill: parent
                radius: Style.cardRadius
                color: Style.lightGray
                clip: true
                Image {
                    anchors.fill: parent
                    source: v.thumbnail || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    opacity: status === Image.Ready ? 1.0 : 0.0
                }
            }

            // Play affordance
            Rectangle {
                anchors.centerIn: parent
                width: units.gu(5.5); height: width
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.5)
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3); height: width
                    name: "media-playback-start"
                    color: Style.textOnBrand
                }
            }

            // Duration badge
            Rectangle {
                visible: (v.duration || "") !== "" && v.duration !== "0"
                anchors { right: parent.right; bottom: parent.bottom; margins: Style.spacingS }
                width: durLabel.width + Style.spacingS
                height: units.gu(2.5)
                radius: Style.durationBadgeRadius
                color: Qt.rgba(0, 0, 0, 0.8)
                Label {
                    id: durLabel
                    anchors.centerIn: parent
                    text: v.duration || ""
                    font.pixelSize: Style.fontXSmall
                    font.weight: Font.DemiBold
                    color: Style.textOnBrand
                }
            }
        }

        // Info: avatar + title + meta
        Row {
            width: parent.width
            spacing: Style.spacingS

            Rectangle {
                width: units.gu(4.5); height: width
                radius: width / 2
                color: Style.iconBackground
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: units.dp(1)
                    source: v.authorImage || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: (v.authorImage || "") !== ""
                }
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.5); height: width
                    name: "contact"
                    color: Style.textSecondary
                    visible: (v.authorImage || "") === ""
                }
            }

            Column {
                width: parent.width - units.gu(4.5) - Style.spacingS
                spacing: units.dp(2)
                Label {
                    width: parent.width
                    text: v.title || ""
                    font.pixelSize: Style.fontRegular
                    font.weight: Font.DemiBold
                    font.family: Style.fontFamily
                    color: Style.textTitle
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: (v.comments || 0) > 0
                        ? (v.author || "") + "  ·  " + (v.comments || 0) + " " + i18n.tr("comments")
                        : (v.author || "")
                    font.pixelSize: Style.fontSmall
                    color: Style.textSecondary
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
    }
}
