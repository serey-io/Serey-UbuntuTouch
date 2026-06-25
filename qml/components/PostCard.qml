import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"

/*
 * A single feed/blog row: thumbnail + title + excerpt + meta. Emits clicked().
 * Expects a view-model produced by Mappers.toPost().
 */
AbstractButton {
    id: root
    property var post: ({})
    // Guard: the delegate may rebind `post` to undefined while the model is
    // cleared/recycled. `p` is always a safe object to read from.
    readonly property var p: post ? post : ({})

    width: parent ? parent.width : units.gu(40)
    implicitHeight: Math.max(Style.thumbSize, content.implicitHeight) + Style.spacingM * 2
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: root.pressed ? Style.pressed : "transparent"
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Style.spacingM
        }
        spacing: Style.spacingM

        Rectangle {
            Layout.preferredWidth: Style.thumbSize
            Layout.preferredHeight: Style.thumbSize
            Layout.alignment: Qt.AlignTop
            radius: Style.radius
            color: Style.divider
            clip: true

            Image {
                anchors.fill: parent
                source: p.thumbnail || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                width: units.gu(3)
                height: width
                name: "stock_image"
                color: Style.textSecondary
                visible: !(p.thumbnail)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spacingXs

            Label {
                Layout.fillWidth: true
                text: p.title || ""
                textSize: Label.Large
                font.weight: Font.DemiBold
                font.family: Style.fontFamily
                color: Style.textPrimary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: p.excerpt || ""
                textSize: Label.Small
                font.family: Style.fontFamily
                color: Style.textSecondary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text.length > 0
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacingM

                Label {
                    text: "@" + (p.author || "")
                    textSize: Label.Small
                    color: Style.brand
                    elide: Text.ElideRight
                    Layout.maximumWidth: units.gu(16)
                }
                Label {
                    text: "▲ " + (p.votes || 0)
                    textSize: Label.Small
                    color: Style.textSecondary
                }
                Label {
                    text: "✦ " + (p.comments || 0)
                    textSize: Label.Small
                    color: Style.textSecondary
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: p.payout || ""
                    textSize: Label.Small
                    color: Style.textSecondary
                    visible: text.length > 0
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
