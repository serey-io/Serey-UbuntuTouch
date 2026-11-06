import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

// platform avatar + name
Item {
    id: root

    property var episode: null
    property real avatarSize: units.gu(2.4)
    property bool centered: false

    readonly property string name: episode ? (episode.communityTitle || episode.author || "") : ""
    readonly property string icon: {
        if (!episode) return "";
        var byId = Config.communityIconFor(episode.communityId);
        if (byId) return byId;
        var raw = episode.communityIcon || "";
        return /^https?:/.test(raw) ? raw : "";
    }

    visible: name.length > 0
    height: visible ? avatarSize : 0

    Row {
        x: root.centered ? Math.max(0, (root.width - width) / 2) : 0
        width: Math.min(implicitWidth, root.width)
        spacing: Style.spacingS
        ReporterAvatar {
            anchors.verticalCenter: parent.verticalCenter
            size: root.avatarSize
            name: root.name
            source: root.icon
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - root.avatarSize - Style.spacingS)
            text: root.name
            font.pixelSize: Style.fontSmall
            font.family: Style.fontFor(text)
            color: Style.textSecondary
            elide: Text.ElideRight
        }
    }
}
