import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PostService.js" as PostService

/*
 * News feed: Trending / New posts, filtered by the selected regional source
 * (community_id from Config). The source is chosen via the global AppHeader
 * community pill and shared app-wide through Config.sourceIndex.
 */
Page {
    id: page

    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property string errorMsg: ""
    property int feedIndex: 0
    // Request generation: bumped on reload() so a late response from a previous
    // community/tab can't append stale rows into the freshly-cleared model.
    property int reqEpoch: 0
    property var inflight: null

    // Zero-height header: the global AppHeader provides the top bar, but giving
    // the Page an explicit header keeps it off Lomiri's deprecated Page.head path.
    header: Item { height: 0 }

    ListModel { id: feedModel; dynamicRoles: true }

    // Source switching now lives in the global AppHeader community pill; the feed
    // just reloads when Config.sourceIndex changes.
    Connections {
        target: Config
        function onSourceIndexChanged() { page.reload(); }
    }

    Connections {
        target: PostActions
        function onHideRequested(author, permlink) {
            for (var i = 0; i < feedModel.count; i++) {
                if (feedModel.get(i).permlink === permlink) {
                    feedModel.remove(i);
                    Toast.show(i18n.tr("Post hidden"));
                    return;
                }
            }
        }
    }

    function feedFn() {
        if (feedIndex === 1) return PostService.listNew;
        return PostService.listTrending;
    }

    function reload() {
        page.reqEpoch++;
        if (inflight) { inflight.abort(); inflight = null; }
        offset = 0;
        endReached = false;
        loading = false;
        errorMsg = "";
        feedModel.clear();
        loadMore();
    }

    function loadMore() {
        if (loading || endReached) return;
        loading = true;
        errorMsg = "";
        var epoch = page.reqEpoch;
        var params = { limit: Config.pageSize, offset: page.offset };
        if (Config.communityId > 0)
            params.community_id = Config.communityId;
        inflight = feedFn()(Config.baseUrl, params, Session.token,
            function (result, rawCount) {
                if (epoch !== page.reqEpoch) return;   // stale response — ignore
                inflight = null;
                loading = false;
                for (var i = 0; i < result.length; i++)
                    feedModel.append(result[i]);
                page.offset += rawCount;
                if (rawCount < Config.pageSize) page.endReached = true;
            },
            function (err) {
                if (epoch !== page.reqEpoch) return;
                inflight = null;
                loading = false;
                page.errorMsg = err.message;
            });
    }

    Component.onCompleted: loadMore()

    SectionTabs {
        id: tabs
        anchors { top: parent.top; left: parent.left; right: parent.right }
        model: [i18n.tr("Trending"), i18n.tr("New")]
        currentIndex: page.feedIndex
        onSelected: {
            page.feedIndex = index;
            page.reload();
        }
    }

    ListView {
        id: list
        anchors { top: tabs.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: feedModel
        cacheBuffer: units.gu(12)

        delegate: PostCard {
            width: list.width
            post: feedModel.get(index)
            onClicked: {
                var p = feedModel.get(index);
                page.pageStack.push(Qt.resolvedUrl("PostDetailPage.qml"),
                    { author: p.author, permlink: p.permlink, title: p.title });
            }
            onRequireLogin: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
            onMoreClicked: PostActions.open(feedModel.get(index))
        }

        // Constant-height footer: a conditional height feeds back into
        // contentHeight/atYEnd and trips a "height" binding loop, so keep it
        // fixed and just toggle the spinner.
        footer: Item {
            width: list.width
            height: units.gu(6)
            ActivityIndicator {
                anchors.centerIn: parent
                running: page.loading && feedModel.count > 0
                visible: running
            }
        }

        onAtYEndChanged: {
            if (atYEnd && !page.loading && !page.endReached && feedModel.count > 0)
                page.loadMore();
        }
    }

    LoadingState {
        anchors.fill: list
        visible: page.loading && feedModel.count === 0
    }
    ErrorState {
        anchors.fill: list
        visible: page.errorMsg !== "" && feedModel.count === 0
        message: page.errorMsg
        onRetry: page.reload()
    }
    EmptyState {
        anchors.fill: list
        visible: !page.loading && page.errorMsg === "" && feedModel.count === 0
        iconName: "stock_note"
        message: i18n.tr("No posts in %1").arg(Config.communityName)
    }

    // Floating compose button
    AbstractButton {
        visible: Session.isLoggedIn
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: Style.spacingM
            bottomMargin: Style.spacingM
        }
        width: Style.fabSize; height: width
        z: 10
        onClicked: {
            page.pageStack.push(Qt.resolvedUrl("CreatePostPage.qml"))
        }

        Rectangle {
            anchors.fill: parent
            radius: Style.fabRadius
            color: Style.brand
        }
        Icon {
            anchors.centerIn: parent
            width: units.gu(3); height: width
            name: "edit"
            color: Style.textOnBrand
        }
    }
}
