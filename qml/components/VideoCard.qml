import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"

/*
 * A video row: wide 16:9 thumbnail with a play badge, title and meta below.
 * Emits clicked(). Expects a view-model from Mappers.toVideo().
 */
AbstractButton {
    id: root
    property var video: ({})

    width: parent ? parent.width : units.gu(40)
    implicitHeight: column.implicitHeight + Style.spacingM * 2
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: root.pressed ? Style.pressed : "transparent"
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.spacingM
        }
        spacing: Style.spacingS

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 9 / 16
            radius: Style.radius
            color: Style.divider
            clip: true

            Image {
                anchors.fill: parent
                source: root.video.thumbnail || ""
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
            Layout.fillWidth: true
            text: root.video.title || ""
            textSize: Label.Large
            font.weight: Font.DemiBold
            color: Style.textPrimary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacingM

            Label {
                text: "@" + (root.video.author || "")
                textSize: Label.Small
                color: Style.brand
                elide: Text.ElideRight
                Layout.maximumWidth: units.gu(20)
            }
            Label {
                text: "▲ " + (root.video.votes || 0)
                textSize: Label.Small
                color: Style.textSecondary
            }
            Item { Layout.fillWidth: true }
            Label {
                text: root.video.date || ""
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
