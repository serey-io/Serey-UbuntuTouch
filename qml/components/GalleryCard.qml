import QtQuick 2.7
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/FollowService.js" as FollowService

/*
 * Gallery feed card (serey-ubutu GalleryCard style): avatar + author + time,
 * a swipeable image carousel (with page dots) cropped to a rounded square-ish
 * frame, a live action row (VoteBar) and a caption. Tapping the image opens
 * the post detail; the action row votes/comments inline.
 */
Item {
    id: root

    property var post: ({})
    readonly property var p: post ? post : ({})
    property bool isFollowing: false

    signal clicked()
    signal requireLogin()
    signal moreClicked()

    onPChanged: {
        root.isFollowing = false;
        if (Session.isLoggedIn && p.author && p.author !== Session.username) {
            FollowService.status(Config.baseUrl, Session.username, p.author,
                // `root` may be null if the delegate was recycled before the
                // async response arrived — guard against the destroyed card.
                function (following) { if (root) root.isFollowing = following; },
                function (err) { /* keep default false */ });
        }
    }

    function toggleFollow() {
        if (!Session.isLoggedIn) {
            Toast.error(i18n.tr("Please log in first."));
            root.requireLogin();
            return;
        }
        var was = root.isFollowing;
        root.isFollowing = !was;
        FollowService.toggle(Config.baseUrl, p.author, was, Session.token,
            function (nowFollowing) {
                root.isFollowing = nowFollowing;
                Toast.show(nowFollowing ? i18n.tr("Following") : i18n.tr("Unfollowed"));
            },
            function (err) {
                root.isFollowing = was;
                Toast.error((err && err.message) ? err.message : i18n.tr("Action failed."));
            });
    }

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
    // images may arrive as a plain JS array (fresh map) or a wrapped
    // ListModel (dynamicRoles re-binding); normalise to a plain array.
    function _images() {
        var v = p.images;
        if (!v) return [];
        if (typeof v.length === "number") return v;
        if (typeof v.count === "number") {
            var out = [];
            for (var i = 0; i < v.count; i++) out.push(v.get(i));
            return out;
        }
        return [];
    }

    width: parent ? parent.width : units.gu(45)
    implicitHeight: col.height

    Column {
        id: col
        width: parent.width

        Item { width: 1; height: Style.spacingS }

        // Header: avatar + author + time
        Item {
            width: parent.width
            height: units.gu(6)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.spacingM
                anchors.rightMargin: Style.spacingM
                spacing: Style.spacingS

                Item {
                    id: galAvatar
                    Layout.preferredWidth: units.gu(4.25)
                    Layout.preferredHeight: units.gu(4.25)
                    Layout.fillHeight: false
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Style.avatarTint(p.author || "")
                        visible: (p.authorImage || "") === ""

                        Label {
                            anchors.centerIn: parent
                            text: (p.author || "?").charAt(0).toUpperCase()
                            font.pixelSize: Style.fontMedium
                            font.bold: true
                            color: Style.brand
                        }
                    }

                    Image {
                        id: galAvatarImg
                        anchors.fill: parent
                        source: p.authorImage || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    Rectangle {
                        id: galAvatarMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }
                    OpacityMask {
                        anchors.fill: parent
                        source: galAvatarImg
                        maskSource: galAvatarMask
                        visible: (p.authorImage || "") !== ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Label {
                        Layout.fillWidth: true
                        text: p.author || ""
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.DemiBold
                        color: Style.textPrimary
                        elide: Text.ElideRight
                    }
                    Label {
                        text: Style.formatTimeAgo(p.date || "")
                        font.pixelSize: Style.fontXSmall
                        color: Style.textSecondary
                    }
                }

                // Follow pill
                Rectangle {
                    visible: (p.author || "") !== "" && p.author !== Session.username
                    Layout.preferredWidth: galFollowLabel.width + units.gu(3)
                    Layout.preferredHeight: units.gu(3.75)
                    Layout.fillHeight: false
                    Layout.alignment: Qt.AlignVCenter
                    radius: height / 2
                    color: root.isFollowing ? Style.surface : Style.brand
                    border.width: root.isFollowing ? units.dp(1.5) : 0
                    border.color: Style.brand

                    Label {
                        id: galFollowLabel
                        anchors.centerIn: parent
                        text: root.isFollowing ? i18n.tr("Following") : i18n.tr("Follow")
                        font.pixelSize: Style.fontXSmall
                        font.weight: Font.DemiBold
                        color: root.isFollowing ? Style.brand : Style.textOnBrand
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleFollow()
                    }
                }

                // More button
                AbstractButton {
                    Layout.preferredWidth: units.gu(3.5)
                    Layout.preferredHeight: units.gu(3.5)
                    Layout.fillHeight: false
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.moreClicked()

                    Label {
                        anchors.centerIn: parent
                        text: "•••"
                        font.pixelSize: Style.fontLarge
                        font.weight: Font.Bold
                        color: Style.textSecondary
                    }
                }
            }
        }

        // Image carousel
        Item {
            id: cover
            width: parent.width
            height: width

            SwipeView {
                id: swipe
                anchors.fill: parent
                clip: true

                Repeater {
                    model: root._images()
                    delegate: Image {
                        source: modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        opacity: status === Image.Ready ? 1.0 : 0.0
                        Rectangle {
                            anchors.fill: parent
                            color: Style.iconBackground
                            visible: parent.status !== Image.Ready
                            z: -1
                        }
                    }
                }
            }

            MouseArea { anchors.fill: parent; onClicked: root.clicked() }

            // Page dots
            Row {
                visible: root._images().length > 1
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Style.spacingS }
                spacing: Style.spacingXs

                Repeater {
                    model: root._images().length
                    delegate: Rectangle {
                        width: units.dp(7); height: units.dp(7)
                        radius: width / 2
                        color: swipe.currentIndex === index ? Style.brand : Style.dotInactive
                    }
                }
            }
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

        // Caption (Lomiri Label has no top/bottomPadding in Components 1.3,
        // so spacing is provided by visible-gated spacer Items — the Column
        // positioner skips invisible children.)
        Item { width: 1; height: Style.spacingXs; visible: (p.caption || "") !== "" }
        Label {
            visible: (p.caption || "") !== ""
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            text: p.caption || ""
            font.pixelSize: Style.fontRegular
            font.family: Style.fontFamily
            color: Style.textPrimary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Item { width: 1; height: Style.spacingS; visible: (p.caption || "") !== "" }

        Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }
    }
}
