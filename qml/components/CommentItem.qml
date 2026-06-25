import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/CommentService.js" as CommentService

/*
 * A single comment row. Indents by `comment.depth` to show reply nesting, and
 * embeds a compact VoteBar (like-toggle) for the comment. Own comments (with a
 * server-assigned permlink) can be deleted; deletion is reported up via
 * deleted(permlink) so the page can drop it from the list.
 */
Item {
    id: item
    property var comment: ({})
    readonly property var c: comment ? comment : ({})

    // Only the author can delete, and only a comment that exists server-side
    // (optimistic local comments carry an empty permlink).
    readonly property bool canDelete: Session.isLoggedIn
                                      && c.author === Session.username
                                      && (c.permlink || "").length > 0
    property bool deleting: false

    signal deleted(string permlink)

    function doDelete() {
        if (deleting)
            return;
        item.deleting = true;
        CommentService.remove(Config.baseUrl, c.permlink, Session.username, Session.token,
            function () { item.deleted(c.permlink); },
            function (err) {
                item.deleting = false;
                Toast.error((err && err.message) ? err.message : i18n.tr("Couldn't delete comment."));
            });
    }

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
            AbstractButton {
                visible: item.canDelete
                enabled: !item.deleting
                height: deleteLabel.height
                width: deleteLabel.width
                onClicked: item.doDelete()
                Label {
                    id: deleteLabel
                    text: item.deleting ? i18n.tr("Deleting…") : i18n.tr("Delete")
                    textSize: Label.Small
                    color: Style.danger
                }
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
