import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"

/*
 * A community/creator row in the Homepage directory: icon + title + domain.
 * Emits clicked(). Expects a view-model from Mappers.toCommunity().
 */
AbstractButton {
    id: root
    property var community: ({})

    width: parent ? parent.width : units.gu(40)
    implicitHeight: units.gu(8)
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: root.pressed ? Style.pressed : "transparent"
    }

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Style.spacingM
        }
        spacing: Style.spacingM

        LomiriShape {
            Layout.preferredWidth: units.gu(5)
            Layout.preferredHeight: units.gu(5)
            radius: "medium"
            backgroundColor: Style.divider
            source: (root.community.icon || "") !== "" ? iconImg : null
            Image { id: iconImg; source: root.community.icon || ""; fillMode: Image.PreserveAspectCrop }
            Icon {
                anchors.centerIn: parent
                width: units.gu(2.5); height: width
                name: "view-grid-symbolic"
                color: Style.textSecondary
                visible: (root.community.icon || "") === ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.community.title || ""
                textSize: Label.Large
                font.weight: Font.DemiBold
                color: Style.textPrimary
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: root.community.dns || ""
                textSize: Label.Small
                color: Style.textSecondary
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        Icon {
            Layout.preferredWidth: units.gu(2)
            Layout.preferredHeight: units.gu(2)
            name: "next"
            color: Style.textSecondary
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
    }
}
