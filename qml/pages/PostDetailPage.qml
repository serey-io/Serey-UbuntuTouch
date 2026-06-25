import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PostService.js" as PostService
import "../services/CommentService.js" as CommentService

/*
 * Full post view. Receives author/permlink (and an optional title for the
 * header) when pushed; fetches the full body + replies from the detail
 * endpoint. Provides upvote/downvote (VoteBar) and a comment composer + list.
 */
Page {
    id: page

    property string author: ""
    property string permlink: ""
    property string title: ""

    property var post: null
    property var comments: []
    property int commentCount: 0
    property bool loading: false
    property bool posting: false
    property string errorMsg: ""

    header: PageHeader {
        title: page.title || i18n.tr("Post")
    }

    function maincategory() {
        if (page.post && page.post.categories && page.post.categories.length > 0)
            return page.post.categories[0];
        return "serey";
    }

    // Flatten the reply tree into a list carrying a `depth` for indentation.
    function flattenComments(list, depth, out) {
        out = out || [];
        if (!list)
            return out;
        for (var i = 0; i < list.length; i++) {
            var c = list[i];
            out.push({ author: c.author, permlink: c.permlink, body: c.body, date: c.date,
                       votes: c.votes, voters: c.voters, depth: depth });
            if (c.replies && c.replies.length)
                page.flattenComments(c.replies, depth + 1, out);
        }
        return out;
    }

    function load() {
        loading = true;
        errorMsg = "";
        PostService.detail(Config.baseUrl, author, permlink, Session.token,
            function (result) {
                loading = false;
                page.post = result.post;
                page.commentCount = result.post.comments;
                page.comments = page.flattenComments(result.replies, 0, []);
            },
            function (err) {
                loading = false;
                page.errorMsg = err.message;
            });
    }

    function pushLogin() {
        page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
    }

    function removeComment(permlink) {
        var out = [];
        for (var i = 0; i < page.comments.length; i++) {
            if (page.comments[i].permlink !== permlink)
                out.push(page.comments[i]);
        }
        page.comments = out;
        page.commentCount = Math.max(0, page.commentCount - 1);
        Toast.success(i18n.tr("Comment deleted"));
    }

    function submitComment() {
        var text = composer.text.trim();
        if (text.length === 0)
            return;
        if (!Session.isLoggedIn) {
            Toast.error(i18n.tr("Please log in first."));
            page.pushLogin();
            return;
        }
        page.posting = true;
        CommentService.create(Config.baseUrl,
            { parentAuthor: page.author, parentPermlink: page.permlink,
              maincategory: page.maincategory(), body: text },
            Session.token,
            function (data) {
                page.posting = false;
                composer.text = "";
                var mine = { author: Session.username, permlink: "", body: text,
                             date: i18n.tr("just now"), votes: 0, voters: [], depth: 0 };
                page.comments = [mine].concat(page.comments);
                page.commentCount = page.commentCount + 1;
                Toast.success(i18n.tr("Comment posted"));
            },
            function (err) {
                page.posting = false;
                Toast.error((err && err.message) ? err.message : i18n.tr("Couldn't post comment."));
            });
    }

    Component.onCompleted: load()

    Flickable {
        id: scroll
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: contentCol.height
        clip: true
        visible: page.post !== null

        Column {
            id: contentCol
            width: scroll.width
            spacing: Style.spacingM

            Item { width: 1; height: Style.spacingS }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.post ? page.post.title : ""
                textSize: Label.XLarge
                font.weight: Font.DemiBold
                font.family: Style.fontFamily
                color: Style.textPrimary
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Style.spacingM * 2
                spacing: Style.spacingM

                Label {
                    text: page.post ? ("@" + page.post.author) : ""
                    textSize: Label.Small
                    color: Style.brand
                }
                Label {
                    text: page.post ? page.post.date : ""
                    textSize: Label.Small
                    color: Style.textSecondary
                }
            }

            Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

            // Interactive vote / comment bar
            VoteBar {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                author: page.author
                permlink: page.permlink
                voteType: "post"
                votes: page.post ? page.post.votes : 0
                flaggers: page.post ? page.post.flaggers.length : 0
                comments: page.commentCount
                payout: page.post ? page.post.payout : ""
                upvoted: page.post && page.post.voters.indexOf(Session.username) >= 0
                flagged: page.post && page.post.flaggers.indexOf(Session.username) >= 0
                onRequireLogin: page.pushLogin()
                onCommentRequested: composer.forceActiveFocus()
            }

            Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

            // Rich-text body
            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.post ? page.post.body : ""
                textFormat: Text.RichText
                font.family: Style.fontFamily
                wrapMode: Text.WordWrap
                color: Style.textPrimary
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

            // --- Comments ---------------------------------------------------
            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Comments (%1)").arg(page.commentCount)
                textSize: Label.Large
                font.weight: Font.DemiBold
                color: Style.textPrimary
            }

            // Composer
            Column {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.spacingS

                TextArea {
                    id: composer
                    width: parent.width
                    autoSize: true
                    maximumLineCount: 6
                    placeholderText: Session.isLoggedIn
                        ? i18n.tr("Write a comment…")
                        : i18n.tr("Log in to comment…")
                    font.family: Style.fontFamily
                }
                Button {
                    text: page.posting ? i18n.tr("Posting…") : i18n.tr("Post comment")
                    color: Style.brand
                    enabled: !page.posting && composer.text.trim().length > 0
                    onClicked: page.submitComment()
                }
            }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.comments.length === 0
                text: i18n.tr("No comments yet. Be the first!")
                textSize: Label.Small
                color: Style.textSecondary
            }

            Repeater {
                model: page.comments
                delegate: CommentItem {
                    width: contentCol.width
                    comment: modelData
                    onDeleted: page.removeComment(permlink)
                }
            }

            Item { width: 1; height: Style.spacingL }
        }
    }

    LoadingState {
        anchors.fill: parent
        visible: page.loading && page.post === null
    }
    ErrorState {
        anchors.fill: parent
        visible: page.errorMsg !== "" && page.post === null
        message: page.errorMsg
        onRetry: page.load()
    }
}
