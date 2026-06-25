import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

/*
 * A single comment row. Indents by `comment.depth` to show reply nesting, and
 * embeds a compact VoteBar (like-toggle) for the comment.
 */
Item {
    id: item
    property var comment: ({})
    readonly property var c: comment ? comment : ({})

    width: parent ? parent.width : units.gu(40)
    implicitHeight: col.implicitHeight + Style.spacingM

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: units.dp(2)
        x: (c.depth || 0) * units.gu(2)
        color: (c.depth || 0) > 0 ? Style.divider : "transparent"
    }

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: Style.spacingM + (c.depth || 0) * units.gu(2)
            rightMargin: Style.spacingM
            topMargin: Style.spacingS
        }
        spacing: Style.spacingXs

        Row {
            spacing: Style.spacingS
            Label {
                text: "@" + (c.author || "")
                textSize: Label.Small
                font.weight: Font.DemiBold
                color: Style.brand
            }
            Label {
                text: c.date || ""
                textSize: Label.Small
                color: Style.textSecondary
            }
        }

        Label {
            width: parent.width
            text: c.body || ""
            font.family: Style.fontFamily
            color: Style.textPrimary
            wrapMode: Text.WordWrap
        }

        VoteBar {
            author: c.author || ""
            permlink: c.permlink || ""
            voteType: "comment"
            showComments: false
            votes: c.votes || 0
            upvoted: (c.voters || []).indexOf(Session.username) >= 0
            width: parent.width
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
    }
}
