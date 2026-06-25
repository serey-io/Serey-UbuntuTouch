import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/VideoService.js" as VideoService

/*
 * Video section: list of videos. Tapping opens VideoDetailPage, passing the
 * already-loaded video view-model (it carries the embed URL).
 */
Page {
    id: page

    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property string errorMsg: ""

    // Zero-height header keeps the Page off Lomiri's deprecated Page.head path;
    // the global AppHeader is the real top bar.
    header: Item { height: 0 }

    ListModel { id: feedModel; dynamicRoles: true }

    // Source switching lives in the global AppHeader community pill; the list
    // just reloads when Config.sourceIndex changes.
    Connections {
        target: Config
        function onSourceIndexChanged() {
            page.reload();
        }
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
        VideoService.listVideos(Config.baseUrl, params, Session.token,
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

    Component.onCompleted: loadMore()

    ListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: feedModel
        cacheBuffer: units.gu(60)

        delegate: VideoCard {
            width: list.width
            video: feedModel.get(index)
            onClicked: page.pageStack.push(Qt.resolvedUrl("VideoDetailPage.qml"),
                { video: feedModel.get(index) })
        }

        footer: Item {
            width: list.width
            height: page.loading ? units.gu(6) : 0
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
        iconName: "camcorder"
        message: i18n.tr("No videos to show")
    }
}
