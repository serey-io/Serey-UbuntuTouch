import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

/*
 * Feed post card (serey-ubutu FeedCard style): avatar + author + relative time,
 * title, rounded cover image with a red category badge, then a live action row
 * (VoteBar) and a hairline divider. Tapping the title or image opens the detail
 * page; the action row votes/comments inline.
 *
 * Consumes the Mappers.toPost view-model. Emits clicked() to open detail, and
 * re-exposes the VoteBar's requireLogin() so the page can route to login.
 */
Item {
    id: root

    property var post: ({})
    // Guard: the delegate may rebind `post` to undefined while the model is
    // cleared/recycled. `p` is always a safe object to read from.
    readonly property var p: post ? post : ({})

    signal clicked()
    signal requireLogin()

    width: parent ? parent.width : units.gu(45)
    implicitHeight: col.height

    // The feed ListModel (dynamicRoles) wraps array fields as nested ListModels,
    // which have `count` but no `indexOf`/`length`. These helpers read either a
    // plain JS array (detail view-models) or a wrapped ListModel safely.
    function _len(v) {
        if (!v) return 0;
        if (typeof v.length === "number") return v.length;
        if (typeof v.count === "number") return v.count;
        return 0;
    }
    function _inList(v, name) {
        if (v && typeof v.indexOf === "function") return v.indexOf(name) >= 0;
        return false;
    }

    Column {
        id: col
        width: parent.width

        // Header: avatar + author + time
        Item {
            width: parent.width
            height: units.gu(6)

            Row {
                anchors {
                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: Style.spacingM; rightMargin: Style.spacingM
                }
                spacing: Style.spacingS

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(4.25); height: width
                    radius: width / 2
                    color: Style.avatarTint(p.author || "")
                    clip: true

                    Label {
                        anchors.centerIn: parent
                        visible: (p.authorImage || "") === ""
                        text: (p.author || "?").charAt(0).toUpperCase()
                        font.pixelSize: Style.fontMedium
                        font.bold: true
                        color: Style.brand
                    }
                    Image {
                        anchors.fill: parent
                        source: p.authorImage || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: (p.authorImage || "") !== ""
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Label {
                        text: p.author || ""
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.DemiBold
                        color: Style.textPrimary
                    }
                    Label {
                        text: Style.formatTimeAgo(p.date || "")
                        font.pixelSize: Style.fontXSmall
                        color: Style.textSecondary
                    }
                }
            }
        }

        // Title
        Label {
            visible: (p.title || "") !== ""
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            text: p.title || ""
            font.pixelSize: Style.fontMedium
            font.family: Style.fontFamily
            color: Style.textPrimary
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            MouseArea { anchors.fill: parent; onClicked: root.clicked() }
        }

        Item { width: 1; height: Style.spacingS }

        // Cover image with category badge
        Item {
            id: cover
            visible: (p.thumbnail || "") !== ""
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            height: visible ? width * 0.56 : 0

            Rectangle {
                anchors.fill: parent
                radius: Style.thumbRadius
                color: Style.iconBackground
                clip: true
                Image {
                    anchors.fill: parent
                    source: p.thumbnail || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    opacity: status === Image.Ready ? 1.0 : 0.0
                }
            }

            Rectangle {
                visible: !!(p.categories && p.categories.length > 0)
                anchors { top: parent.top; right: parent.right; topMargin: Style.spacingS; rightMargin: Style.spacingS }
                width: catLabel.width + Style.spacingS
                height: units.gu(2.5)
                radius: units.dp(4)
                color: Style.accentRed
                Label {
                    id: catLabel
                    anchors.centerIn: parent
                    text: (p.categories && p.categories.length > 0) ? p.categories[0] : ""
                    font.pixelSize: Style.fontXSmall
                    font.weight: Font.DemiBold
                    color: Style.textOnBrand
                }
            }

            MouseArea { anchors.fill: parent; onClicked: root.clicked() }
        }

        // Excerpt (shown when there is no cover image)
        Label {
            visible: (p.thumbnail || "") === "" && (p.excerpt || "") !== ""
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            text: p.excerpt || ""
            font.pixelSize: Style.fontRegular
            font.family: Style.fontFamily
            color: Style.textSecondary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            MouseArea { anchors.fill: parent; onClicked: root.clicked() }
        }

        Item { width: 1; height: Style.spacingS }

        // Action row (live voting)
        VoteBar {
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            author: p.author || ""
            permlink: p.permlink || ""
            voteType: "post"
            votes: p.votes || 0
            flaggers: root._len(p.flaggers)
            comments: p.comments || 0
            payout: p.payout || ""
            upvoted: root._inList(p.voters, Session.username)
            flagged: root._inList(p.flaggers, Session.username)
            onRequireLogin: root.requireLogin()
            onCommentRequested: root.clicked()
        }

        Item { width: 1; height: Style.spacingS }

        Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }
    }
}
