import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PostService.js" as PostService

/*
 * News feed: Trending / Hot / New posts, filtered by the selected regional
 * source (community_id from Config). The source is chosen via the header
 * Sections control and shared app-wide through Config.sourceIndex.
 */
Page {
    id: page

    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property string errorMsg: ""
    property int feedIndex: 0

    header: PageHeader {
        title: i18n.tr("News")
        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18n.tr("Refresh")
                onTriggered: page.reload()
            }
        ]
        extension: Sections {
            id: sourceSections
            anchors { left: parent.left; leftMargin: units.gu(2); bottom: parent.bottom }
            model: Config.sourceNames
            onSelectedIndexChanged: if (selectedIndex !== Config.sourceIndex) Config.sourceIndex = selectedIndex
        }
    }

    ListModel { id: feedModel; dynamicRoles: true }

    Connections {
        target: Config
        function onSourceIndexChanged() {
            sourceSections.selectedIndex = Config.sourceIndex;
            page.reload();
        }
    }

    function feedFn() {
        if (feedIndex === 1) return PostService.listHot;
        if (feedIndex === 2) return PostService.listNew;
        return PostService.listTrending;
    }

    function reload() {
        offset = 0;
        endReached = false;
        errorMsg = "";
        feedModel.clear();
        loadMore();
    }

    function loadMore() {
        if (loading || endReached) return;
        loading = true;
        errorMsg = "";
        var params = { limit: Config.pageSize, offset: page.offset };
        if (Config.communityId > 0)
            params.community_id = Config.communityId;
        feedFn()(Config.baseUrl, params, Session.token,
            function (result) {
                loading = false;
                for (var i = 0; i < result.length; i++)
                    feedModel.append(result[i]);
                page.offset += result.length;
                if (result.length < Config.pageSize) page.endReached = true;
            },
            function (err) {
                loading = false;
                page.errorMsg = err.message;
            });
    }

    Component.onCompleted: {
        sourceSections.selectedIndex = Config.sourceIndex;
        loadMore();
    }

    SectionTabs {
        id: tabs
        anchors { top: page.header.bottom; left: parent.left; right: parent.right }
        model: [i18n.tr("Trending"), i18n.tr("Hot"), i18n.tr("New")]
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
        cacheBuffer: units.gu(40)

        delegate: PostCard {
            width: list.width
            post: feedModel.get(index)
            onClicked: {
                var p = feedModel.get(index);
                page.pageStack.push(Qt.resolvedUrl("PostDetailPage.qml"),
                    { author: p.author, permlink: p.permlink, title: p.title });
            }
        }

        footer: Item {
            width: list.width
            height: page.loading && feedModel.count > 0 ? units.gu(6) : 0
            ActivityIndicator {
                anchors.centerIn: parent
                running: page.loading && feedModel.count > 0
            }
        }

        onContentYChanged: {
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
}
