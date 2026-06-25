import QtQuick 2.7
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/CommentService.js" as CommentService

/*
 * A single comment row (iOS-style): circular avatar + author + relative time
 * + "•••" menu, body text, a like + reply action row, and — when the comment
 * has replies — a "Hide replies / N replies" toggle that reveals a nested,
 * left-indented sub-tree (recursive CommentItem). Own comments (with a
 * server-assigned permlink) can be deleted; deletion is reported up via
 * deleted(permlink) so the page drops it from the tree.
 */
Item {
    id: item
    property var comment: ({})
    readonly property var c: comment ? comment : ({})
    readonly property var replies: c.replies || []
    property bool repliesExpanded: true
    property bool topLevel: true

    // Only the author can delete, and only a comment that exists server-side
    // (optimistic local comments carry an empty permlink).
    readonly property bool canDelete: Session.isLoggedIn
                                      && c.author === Session.username
                                      && (c.permlink || "").length > 0
    property bool deleting: false

    signal deleted(string permlink)
    signal replyRequested(var comment)

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
            leftMargin: Style.spacingM
            rightMargin: Style.spacingM
            topMargin: Style.spacingS
        }
        spacing: Style.spacingXs

        // Author row: avatar + name + time on the left, ••• on the right
        Item {
            width: parent.width
            height: nameCol.height

            Item {
                id: avatar
                anchors.verticalCenter: nameCol.verticalCenter
                width: units.gu(3.5); height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Style.avatarTint(c.author || "")
                    visible: (c.authorImage || "") === ""

                    Label {
                        anchors.centerIn: parent
                        text: (c.author || "?").charAt(0).toUpperCase()
                        font.pixelSize: Style.fontSmall
                        font.bold: true
                        color: Style.brand
                    }
                }

                // Rectangle.clip only clips to the bounding box (not rounded
                // corners), so the photo is masked instead, for a true circle.
                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: c.authorImage || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
                OpacityMask {
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: avatarMask
                    visible: (c.authorImage || "") !== ""
                }
            }

            Row {
                anchors {
                    left: avatar.right
                    leftMargin: Style.spacingS
                    right: moreButton.left
                    verticalCenter: avatar.verticalCenter
                }
                spacing: Style.spacingXs

                Label {
                    text: c.author || ""
                    font.pixelSize: Style.fontSmall
                    font.weight: Font.DemiBold
                    color: Style.textPrimary
                }
                Label {
                    text: "· " + Style.formatTimeAgo(c.date || "")
                    font.pixelSize: Style.fontXSmall
                    color: Style.textSecondary
                }
            }

            AbstractButton {
                id: moreButton
                visible: item.canDelete
                enabled: !item.deleting
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: units.gu(3); height: units.gu(3)
                onClicked: item.doDelete()

                Label {
                    anchors.centerIn: parent
                    text: item.deleting ? "…" : "•••"
                    font.pixelSize: Style.fontMedium
                    font.weight: Font.Bold
                    color: Style.textSecondary
                }
            }
        }

        Label {
            width: parent.width
            x: units.gu(3.5) + Style.spacingS
            text: c.body || ""
            font.pixelSize: Style.fontRegular
            font.family: Style.fontFamily
            color: Style.textPrimary
            wrapMode: Text.WordWrap
        }

        // Like + reply action row
        Row {
            x: units.gu(3.5) + Style.spacingS
            spacing: Style.spacingM

            VoteBar {
                anchors.verticalCenter: parent.verticalCenter
                author: c.author || ""
                permlink: c.permlink || ""
                voteType: "comment"
                showComments: false
                showShare: false
                votes: c.votes || 0
                upvoted: (c.voters || []).indexOf(Session.username) >= 0
                width: units.gu(8)
            }

            AbstractButton {
                anchors.verticalCenter: parent.verticalCenter
                width: replyRow.implicitWidth
                height: units.gu(3.5)
                onClicked: item.replyRequested(c)

                Row {
                    id: replyRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacingXs
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(2.2); height: width
                        name: "message"
                        color: Style.textSecondary
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18n.tr("Reply")
                        font.pixelSize: Style.fontSmall
                        color: Style.textSecondary
                    }
                }
            }
        }

        // Replies toggle
        AbstractButton {
            visible: item.replies.length > 0
            x: units.gu(3.5) + Style.spacingS
            width: toggleLabel.implicitWidth
            height: units.gu(3)
            onClicked: item.repliesExpanded = !item.repliesExpanded

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spacingXs
                Label {
                    id: toggleLabel
                    text: item.repliesExpanded
                        ? i18n.tr("Hide replies")
                        : i18n.tr("%1 replies").arg(item.replies.length)
                    font.pixelSize: Style.fontSmall
                    font.weight: Font.DemiBold
                    color: Style.textSecondary
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(1.6); height: width
                    name: item.repliesExpanded ? "up" : "down"
                    color: Style.textSecondary
                }
            }
        }

        // Nested replies, indented with a vertical guide line
        Item {
            visible: item.repliesExpanded && item.replies.length > 0
            width: parent.width
            height: visible ? repliesCol.height : 0

            Rectangle {
                x: units.gu(1.75) - units.dp(1)
                width: units.dp(2)
                height: parent.height
                color: Style.divider
            }

            Column {
                id: repliesCol
                x: units.gu(3.5)
                width: parent.width - x

                // A QML type cannot instantiate itself by name within its own
                // file ("instantiated recursively"), so nested replies are
                // loaded dynamically instead of via a direct CommentItem {}.
                Repeater {
                    model: item.replies
                    delegate: Loader {
                        id: replyLoader
                        width: repliesCol.width
                        property var replyData: modelData
                        Component.onCompleted: setSource(Qt.resolvedUrl("CommentItem.qml"), {
                            comment: replyData,
                            topLevel: false
                        })
                        Connections {
                            target: replyLoader.item
                            onDeleted: item.deleted(permlink)
                            onReplyRequested: item.replyRequested(comment)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Style.divider
        visible: item.topLevel
    }
}
