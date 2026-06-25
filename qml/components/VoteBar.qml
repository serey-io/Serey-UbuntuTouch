import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/VoteService.js" as VoteService

/*
 * Upvote / downvote / comment action row for a post, video or comment.
 * Self-contained: gates on login, posts to VoteService, updates its own counts
 * optimistically and reports outcome via Toast. `voteType` is "post" (default)
 * or "comment" (a like-toggle; flagging is disabled by the backend).
 *
 * Emits requireLogin() when an action needs auth, and commentRequested() when
 * the comment affordance is tapped.
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

    readonly property bool allowFlag: voteType !== "comment"

    signal requireLogin()
    signal commentRequested()

    spacing: Style.spacingL

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
        Layout.preferredHeight: units.gu(4)
        Layout.preferredWidth: upRow.implicitWidth
        enabled: !bar.busy
        onClicked: bar.doUpvote()
        Row {
            id: upRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacingXs
            Label {
                text: "▲"
                font.pixelSize: units.gu(2)
                color: bar.upvoted ? Style.brand : Style.textSecondary
            }
            Label {
                text: bar.votes
                anchors.verticalCenter: parent.verticalCenter
                color: bar.upvoted ? Style.brand : Style.textSecondary
            }
        }
    }

    // Downvote / flag
    AbstractButton {
        visible: bar.allowFlag
        Layout.preferredHeight: units.gu(4)
        Layout.preferredWidth: downRow.implicitWidth
        enabled: !bar.busy
        onClicked: bar.doFlag()
        Row {
            id: downRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacingXs
            Label {
                text: "▼"
                font.pixelSize: units.gu(2)
                color: bar.flagged ? Style.danger : Style.textSecondary
            }
            Label {
                text: bar.flaggers
                anchors.verticalCenter: parent.verticalCenter
                color: bar.flagged ? Style.danger : Style.textSecondary
            }
        }
    }

    // Comments
    AbstractButton {
        visible: bar.showComments
        Layout.preferredHeight: units.gu(4)
        Layout.preferredWidth: cmtRow.implicitWidth
        onClicked: bar.commentRequested()
        Row {
            id: cmtRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacingXs
            Label {
                text: "✦"
                font.pixelSize: units.gu(2)
                color: Style.textSecondary
            }
            Label {
                text: bar.comments
                anchors.verticalCenter: parent.verticalCenter
                color: Style.textSecondary
            }
        }
    }

    Item { Layout.fillWidth: true }

    // Busy indicator / payout
    ActivityIndicator {
        running: bar.busy
        visible: bar.busy
        Layout.preferredHeight: units.gu(2.5)
        Layout.preferredWidth: units.gu(2.5)
    }
    Label {
        visible: !bar.busy && bar.payout.length > 0
        text: bar.payout
        textSize: Label.Small
        color: Style.textSecondary
    }
}
