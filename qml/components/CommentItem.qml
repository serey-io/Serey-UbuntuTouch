import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/CommentService.js" as CommentService

/*
 * A single comment row (serey-ubutu style): avatar + author + relative time,
 * body, and a compact like-toggle VoteBar. Indents by `comment.depth` to show
 * reply nesting. Own comments (with a server-assigned permlink) can be deleted;
 * deletion is reported up via deleted(permlink) so the page drops it.
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

        // Author row: avatar + name + time on the left, delete on the right
        Item {
            width: parent.width
            height: nameCol.height

            Row {
                anchors.left: parent.left
                spacing: Style.spacingS

                Rectangle {
                    anchors.verticalCenter: nameCol.verticalCenter
                    width: units.gu(3.5); height: width
                    radius: width / 2
                    color: Style.avatarTint(c.author || "")
                    clip: true
                    Label {
                        anchors.centerIn: parent
                        visible: (c.authorImage || "") === ""
                        text: (c.author || "?").charAt(0).toUpperCase()
                        font.pixelSize: Style.fontSmall
                        font.bold: true
                        color: Style.brand
                    }
                    Image {
                        anchors.fill: parent
                        source: c.authorImage || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: (c.authorImage || "") !== ""
                    }
                }

                Column {
                    id: nameCol
                    spacing: 0
                    Label {
                        text: c.author || ""
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.DemiBold
                        color: Style.textPrimary
                    }
                    Label {
                        text: Style.formatTimeAgo(c.date || "")
                        font.pixelSize: Style.fontXSmall
                        color: Style.textSecondary
                    }
                }
            }

            AbstractButton {
                visible: item.canDelete
                enabled: !item.deleting
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                height: deleteLabel.height + Style.spacingXs
                width: deleteLabel.width + Style.spacingS
                onClicked: item.doDelete()
                Label {
                    id: deleteLabel
                    anchors.centerIn: parent
                    text: item.deleting ? i18n.tr("Deleting…") : i18n.tr("Delete")
                    font.pixelSize: Style.fontXSmall
                    color: Style.danger
                }
            }
        }

        Label {
            width: parent.width
            text: c.body || ""
            font.pixelSize: Style.fontRegular
            font.family: Style.fontFamily
            color: Style.textPrimary
            wrapMode: Text.WordWrap
        }

        VoteBar {
            author: c.author || ""
            permlink: c.permlink || ""
            voteType: "comment"
            showComments: false
            showShare: false
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
