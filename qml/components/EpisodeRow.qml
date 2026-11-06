import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

// podcast episode row
Item {
    id: root

    property var episode: null
    readonly property bool isCurrent: (Player.current, Player.isCurrent(episode))
    readonly property bool saved: (Downloads.rev, !!episode && Downloads.isSaved(Player.key(episode)))

    width: parent ? parent.width : 0
    height: Math.max(cover.height, info.height)

    CoverArt {
        id: cover
        width: units.gu(9); height: width
        episode: root.episode
        decodeWidth: units.gu(18)

        // now playing
        Rectangle {
            anchors.fill: parent
            visible: root.isCurrent
            radius: Style.thumbRadius
            color: Qt.rgba(0, 0, 0, 0.5)
            Icon {
                anchors.centerIn: parent
                width: units.gu(3); height: width
                name: Player.playing ? "media-playback-pause" : "media-playback-start"
                color: "white"
            }
        }
    }

    Column {
        id: info
        anchors { left: cover.right; right: badges.left; leftMargin: Style.spacingM; rightMargin: Style.spacingS; verticalCenter: parent.verticalCenter }
        spacing: Style.spacingXs

        Label {
            width: parent.width
            visible: text.length > 0
            text: root.episode ? [Lang.tr("Season") + " " + root.episode.seasonNumber, root.episode.episodeLabel, root.episode.duration].filter(function (s) { return s; }).join(" · ") : ""
            font.pixelSize: Style.fontXSmall
            color: root.isCurrent ? Style.brand : Style.textSecondary
        }
        Label {
            width: parent.width
            text: root.episode ? root.episode.title : ""
            font.pixelSize: Style.fontRegular
            font.family: Style.fontFor(text)
            font.weight: Font.DemiBold
            color: root.isCurrent ? Style.brand : Style.textPrimary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        PublisherLine {
            width: parent.width
            episode: root.episode
        }
    }

    Row {
        id: badges
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Style.spacingXs
        Icon {
            visible: root.saved
            width: visible ? units.gu(2) : 0; height: units.gu(2)
            name: "save-to"
            color: Style.positive
        }
        Icon {
            visible: !!root.episode && root.episode.isLocked
            width: visible ? units.gu(2.2) : 0; height: units.gu(2.2)
            name: "lock"
            color: Style.textSecondary
        }
    }
}
