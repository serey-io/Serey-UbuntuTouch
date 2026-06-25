import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/VoteService.js" as VoteService

/*
 * Upvote / downvote / comment / share action row for a post, video or comment.
 * Self-contained: gates on login, posts to VoteService, updates its own counts
 * optimistically and reports outcome via Toast. `voteType` is "post" (default)
 * or "comment" (a like-toggle; flagging is disabled by the backend).
 *
 * Emits requireLogin() when an action needs auth, and commentRequested() when
 * the comment affordance is tapped. Styling follows the serey-ubutu action bar:
 * Suru icons + counts, right-aligned SEREY coin pill.
 */
RowLayout {
    id: bar

    property string author: ""
    property string permlink: ""
    property string voteType: "post"

    property int votes: 0
    property int flaggers: 0
    property int comments: 0
    property string payout: ""

    property bool upvoted: false
    property bool flagged: false
    property bool busy: false
    property bool showComments: true
    property bool showShare: true

    readonly property bool allowFlag: voteType !== "comment"
    readonly property string shareUrl: (author.length > 0 && permlink.length > 0)
        ? ("https://serey.io/authors/@" + author + "/" + permlink) : ""

    signal requireLogin()
    signal commentRequested()

    spacing: Style.spacingM

    function _guard() {
        if (!Session.isLoggedIn) {
            Toast.error(i18n.tr("Please log in first."));
            bar.requireLogin();
            return false;
        }
        return !bar.busy;
    }
    function _apply(r) {
        bar.busy = false;
        bar.votes = r.voterCount;
        bar.flaggers = r.flaggerCount;
        if (r.payout)
            bar.payout = r.payout;
    }
    function _fail(e) {
        bar.busy = false;
        Toast.error((e && e.message) ? e.message : i18n.tr("Action failed."));
    }

    function doUpvote() {
        if (!_guard())
            return;
        bar.busy = true;
        if (bar.upvoted) {
            VoteService.removeVote(Config.baseUrl, author, permlink, voteType, Session.token,
                function (r) { bar.upvoted = false; _apply(r); Toast.show(i18n.tr("Vote removed")); }, _fail);
        } else {
            VoteService.upvote(Config.baseUrl, author, permlink, voteType, Session.token,
                function (r) { bar.upvoted = true; bar.flagged = false; _apply(r);
                               Toast.success(voteType === "comment" ? i18n.tr("Liked") : i18n.tr("Upvoted")); }, _fail);
        }
    }
    function doFlag() {
        if (!allowFlag || !_guard())
            return;
        bar.busy = true;
        if (bar.flagged) {
            VoteService.removeVote(Config.baseUrl, author, permlink, voteType, Session.token,
                function (r) { bar.flagged = false; _apply(r); Toast.show(i18n.tr("Vote removed")); }, _fail);
        } else {
            VoteService.flag(Config.baseUrl, author, permlink, voteType, Session.token,
                function (r) { bar.flagged = true; bar.upvoted = false; _apply(r); Toast.show(i18n.tr("Flagged")); }, _fail);
        }
    }

    // Upvote / like
    AbstractButton {
        Layout.preferredHeight: units.gu(3.5)
        Layout.preferredWidth: upRow.implicitWidth
        enabled: !bar.busy
        onClicked: bar.doUpvote()
        Row {
            id: upRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacingXs
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(2.5); height: width
                name: "like"
                color: bar.upvoted ? Style.brand : Style.textPrimary
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.votes
                font.pixelSize: Style.fontRegular
                color: bar.upvoted ? Style.brand : Style.textPrimary
            }
        }
    }

    // Downvote / flag
    AbstractButton {
        visible: bar.allowFlag
        Layout.preferredHeight: units.gu(3.5)
        Layout.preferredWidth: downRow.implicitWidth
        enabled: !bar.busy
        onClicked: bar.doFlag()
        Row {
            id: downRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacingXs
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(2.5); height: width
                name: "thumb-down"
                color: bar.flagged ? Style.accentRed : Style.textPrimary
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.flaggers
                font.pixelSize: Style.fontRegular
                color: bar.flagged ? Style.accentRed : Style.textPrimary
            }
        }
    }

    // Comments
    AbstractButton {
        visible: bar.showComments
        Layout.preferredHeight: units.gu(3.5)
        Layout.preferredWidth: cmtRow.implicitWidth
        onClicked: bar.commentRequested()
        Row {
            id: cmtRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacingXs
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(2.5); height: width
                name: "message"
                color: Style.textPrimary
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.comments
                font.pixelSize: Style.fontRegular
                color: Style.textPrimary
            }
        }
    }

    // Share
    AbstractButton {
        visible: bar.showShare && bar.shareUrl.length > 0
        Layout.preferredHeight: units.gu(3.5)
        Layout.preferredWidth: units.gu(3)
        onClicked: Qt.openUrlExternally(bar.shareUrl)
        Icon {
            anchors.centerIn: parent
            width: units.gu(2.5); height: width
            name: "share"
            color: Style.textPrimary
        }
    }

    Item { Layout.fillWidth: true }

    // Busy indicator / payout pill
    ActivityIndicator {
        running: bar.busy
        visible: bar.busy
        Layout.preferredHeight: units.gu(2.5)
        Layout.preferredWidth: units.gu(2.5)
    }
    CoinValue {
        visible: !bar.busy && bar.payout.length > 0
        value: bar.payout
    }
}
