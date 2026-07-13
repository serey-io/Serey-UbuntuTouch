pragma Singleton
import QtQuick 2.7

QtObject {
    property var post: null
    property bool visible: false
    // What kind of content the menu was opened for: "blog" | "gallery" | "video".
    // Drives owner actions (e.g. Edit is hidden for video — no video editor).
    property string kind: "blog"
    // The page whose card opened the sheet. Edit handlers must check
    // `PostActions.origin === page` instead of `page.visible`: in the wide
    // master-detail layout two list pages can be visible at once, and a
    // visible-only guard would push two composers for one edit.
    property var origin: null

    signal hideRequested(string author, string permlink)
    signal editRequested(var post)
    signal postDeleted(string author, string permlink)
    // Emitted after an in-place edit (e.g. video caption) succeeds, so pages
    // showing the post can refresh their copy without a full reload.
    signal postUpdated(string author, string permlink, string title, string body)
    signal userBlocked(string username)
    signal userUnblocked(string username)
    // Emitted when a detail page's comment count changes (add/delete), so feed
    // pages can patch the row's count without a full reload.
    signal commentCountChanged(string permlink, int count)

    function open(postData, postKind, originPage) {
        post = postData;
        kind = postKind || "blog";
        origin = originPage || null;
        visible = true;
    }
    function close() {
        visible = false;
        post = null;
    }
}
