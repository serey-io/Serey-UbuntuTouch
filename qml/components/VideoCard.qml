import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"

/*
 * A video row: wide 16:9 thumbnail with a play badge, title and meta below.
 * Emits clicked(). Expects a view-model from Mappers.toVideo().
 *
 * Uses a plain Column (not ColumnLayout) for the outer stack: sizing the card
 * from a Layout's implicitHeight while the Layout is anchored produces a
 * binding loop, whereas a Column's height is a plain sum of its children.
 */
AbstractButton {
    id: root
    property var video: ({})
    // Guard: the delegate may rebind `video` to undefined while the model is
    // cleared/recycled. `v` is always a safe object to read from.
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

        Rectangle {
            id: thumb
            width: parent.width
            height: width * 9 / 16
            radius: Style.radius
            color: Style.divider
            clip: true

            Image {
                anchors.fill: parent
                source: v.thumbnail || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                width: units.gu(5)
                height: width
                name: "media-playback-start"
                color: Style.textOnBrand
            }
        }

        Label {
            width: parent.width
            text: v.title || ""
            textSize: Label.Large
            font.weight: Font.DemiBold
            font.family: Style.fontFamily
            color: Style.textPrimary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        RowLayout {
            width: parent.width
            spacing: Style.spacingM

            Label {
                text: "@" + (v.author || "")
                textSize: Label.Small
                color: Style.brand
                elide: Text.ElideRight
                Layout.maximumWidth: units.gu(20)
            }
            Label {
                text: "▲ " + (v.votes || 0)
                textSize: Label.Small
                color: Style.textSecondary
            }
            Item { Layout.fillWidth: true }
            Label {
                text: v.date || ""
                textSize: Label.Small
                color: Style.textSecondary
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
    }
}
