import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PostService.js" as PostService

/*
 * Full post view. Receives author/permlink (and an optional title for the
 * header) when pushed; fetches the full body + comment count from the detail
 * endpoint. The HTML body is rendered as rich text.
 */
Page {
    id: page

    property string author: ""
    property string permlink: ""
    property string title: ""

    property var post: null
    property bool loading: false
    property string errorMsg: ""

    header: PageHeader {
        title: page.title || i18n.tr("Post")
    }

    function load() {
        loading = true;
        errorMsg = "";
        PostService.detail(Config.baseUrl, author, permlink, Session.token,
            function (result) {
                loading = false;
                page.post = result.post;
            },
            function (err) {
                loading = false;
                page.errorMsg = err.message;
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

            // Meta header
            Item { width: 1; height: Style.spacingS }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.post ? page.post.title : ""
                textSize: Label.XLarge
                font.weight: Font.DemiBold
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
                Item { width: units.gu(1); height: 1 }
                Label {
                    text: page.post ? ("▲ " + page.post.votes) : ""
                    textSize: Label.Small
                    color: Style.textSecondary
                }
                Label {
                    text: page.post ? ("✦ " + page.post.comments) : ""
                    textSize: Label.Small
                    color: Style.textSecondary
                }
            }

            Rectangle {
                width: parent.width
                height: units.dp(1)
                color: Style.divider
            }

            // Rich-text body
            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.post ? page.post.body : ""
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
                color: Style.textPrimary
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.post && page.post.payout ? i18n.tr("Payout: %1").arg(page.post.payout) : ""
                textSize: Label.Small
                color: Style.textSecondary
                visible: text.length > 0
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
