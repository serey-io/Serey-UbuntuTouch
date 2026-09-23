import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService
import "../services/VideoService.js" as VideoService
import "../services/CopyrightService.js" as CopyrightService

// Serey link -> tappable post preview; other links -> browser row
Rectangle {
    id: root

    property string link: ""
    // Stack to open the post on
    property var stack: null

    // Resolved state
    property var post: null
    property var video: null
    property var postId: null
    property bool loading: false
    readonly property var parsed: CopyrightService.parseContentLink(root.link)
    readonly property bool isVideo: /video-component/i.test(root.link)
    readonly property bool found: !!root.post && (root.post.permlink || "") !== ""

    width: parent ? parent.width : units.gu(40)
    height: units.gu(10)
    radius: Style.cardRadius
    color: "transparent"
    border.width: units.dp(1)
    border.color: Style.divider

    // Debounce typed links
    onLinkChanged: resolveTimer.restart()
    Component.onCompleted: resolve()
    Timer { id: resolveTimer; interval: 400; onTriggered: root.resolve() }

    property string _resolved: "-"
    function resolve() {
        if (root._resolved === root.link) return;
        root._resolved = root.link;
        root.post = null; root.video = null; root.postId = null;
        if (!root.parsed) return;
        var a = root.parsed.author, pl = root.parsed.permlink;
        root.loading = true;
        PostService.detail(Config.baseUrl, a, pl, Session.token,
            function (res) {
                root.loading = false;
                var p = res && res.post;
                if (p && p.permlink) { root.post = p; root.postId = p.id; }
            },
            function () { root.loading = false; });
        // Video page needs its own shape
        if (root.isVideo)
            VideoService.detail(Config.baseUrl, a, pl, Session.token,
                function (v) { if (v && v.permlink) root.video = v; }, function () {});
    }

    function open() {
        if (!root.found) { if (root.link) Qt.openUrlExternally(root.link); return; }
        if (!root.stack) return;
        if (root.isVideo && root.video)
            root.stack.push(Qt.resolvedUrl("../pages/VideoDetailPage.qml"), { video: root.video, allowSidePanel: false });
        else
            root.stack.push(Qt.resolvedUrl("../pages/PostDetailPage.qml"),
                { author: root.post.author, permlink: root.post.permlink, title: root.post.title,
                  seedPost: root.post, allowSidePanel: false });
    }

    AbstractButton {
        anchors.fill: parent
        onClicked: root.open()
    }

    Row {
        anchors { fill: parent; margins: Style.spacingS }
        spacing: Style.spacingM

        // Thumb or link glyph
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: units.gu(12); height: units.gu(7.5)
            Rectangle { anchors.fill: parent; radius: Style.thumbRadius; color: Style.iconBackground }
            RoundedThumb {
                anchors.fill: parent
                readonly property string src: root.video ? (root.video.thumbnail || "")
                                              : (root.post ? (root.post.thumbnail || "") : "")
                visible: src !== ""
                source: src
                decodeWidth: units.gu(14)
            }
            Icon {
                anchors.centerIn: parent
                visible: !root.loading && !root.found
                width: units.gu(3); height: width
                name: "external-link"
                color: Style.textSecondary
            }
            Rectangle {
                anchors.centerIn: parent
                visible: root.found && root.isVideo
                width: units.gu(4); height: width; radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.55)
                Icon { anchors.centerIn: parent; width: units.gu(2); height: width; name: "media-playback-start"; color: "white" }
            }
            ActivityIndicator { anchors.centerIn: parent; running: root.loading; visible: running }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - units.gu(12) - parent.spacing - chevron.width - parent.spacing
            spacing: units.dp(2)
            Label {
                width: parent.width
                text: root.found ? (root.post.title || "")
                      : root.loading ? Lang.tr("Loading…")
                      : root.parsed ? Lang.tr("Post not found")
                      : Lang.tr("External link")
                font.pixelSize: Style.fontRegular
                font.weight: Font.DemiBold
                font.family: Style.fontFor(text)
                color: Style.textPrimary
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: root.found ? ("@" + root.post.author + "  ·  " + Style.formatTimeAgo(root.post.date || ""))
                                 : root.link
                font.pixelSize: Style.fontXSmall
                font.family: Style.fontFor(text)
                color: Style.textSecondary
                elide: root.found ? Text.ElideRight : Text.ElideMiddle
            }
        }

        Icon {
            id: chevron
            anchors.verticalCenter: parent.verticalCenter
            width: units.gu(2); height: width
            name: root.found ? "go-next" : "external-link"
            color: Style.textSecondary
        }
    }
}
