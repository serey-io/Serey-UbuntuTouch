import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

// now-playing bar above nav
Rectangle {
    id: root

    signal opened()

    color: Style.navigationBg

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: units.dp(1)
        color: Style.divider
    }
    // progress line
    Rectangle {
        anchors { left: parent.left; top: parent.top }
        height: units.dp(2)
        width: Player.duration > 0 ? parent.width * Player.position / Player.duration : 0
        color: Style.brand
    }

    AbstractButton {
        anchors { left: parent.left; right: controls.left; top: parent.top; bottom: parent.bottom }
        onClicked: root.opened()

        CoverArt {
            id: art
            anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
            width: units.gu(4.5); height: width
            episode: Player.current
            decodeWidth: units.gu(9)
        }
        Column {
            anchors { left: art.right; right: parent.right; leftMargin: Style.spacingS; rightMargin: Style.spacingS; verticalCenter: parent.verticalCenter }
            Label {
                width: parent.width
                text: Player.current ? Player.current.title : ""
                font.pixelSize: Style.fontSmall
                font.family: Style.fontFor(text)
                font.weight: Font.DemiBold
                color: Style.textPrimary
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: Player.fmt(Player.position) + (Player.duration > 0 ? " / " + Player.fmt(Player.duration) : "")
                font.pixelSize: Style.fontXSmall
                color: Style.textSecondary
            }
        }
        KeyTapArea { onActivated: root.opened() }
    }

    Row {
        id: controls
        anchors { right: parent.right; rightMargin: Style.spacingS; verticalCenter: parent.verticalCenter }
        PlayerButton { icon: "media-seek-backward"; onClicked: Player.seekBy(-15000) }
        PlayerButton {
            busy: Player.buffering
            icon: Player.playing ? "media-playback-pause" : "media-playback-start"
            onClicked: Player.toggle()
        }
        PlayerButton { icon: "close"; onClicked: Player.stop() }
    }
}
