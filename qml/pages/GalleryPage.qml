import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PostService.js" as PostService

/*
 * Gallery feed: image-only posts from the selected regional source
 * (community_id from Config), rendered as swipeable carousels via
 * GalleryCard. Mirrors NewsPage's pagination/reload pattern.
 */
Page {
    id: page

    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property string errorMsg: ""

    header: Item { height: 0 }

    ListModel { id: galleryModel; dynamicRoles: true }

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
        galleryModel.clear();
        loadMore();
    }

    function loadMore() {
        if (loading || endReached) return;
        loading = true;
        errorMsg = "";
        var params = { limit: Config.pageSize, offset: page.offset };
        if (Config.communityId > 0)
            params.community_id = Config.communityId;
        PostService.listGallery(Config.baseUrl, params, Session.token,
            function (result) {
                loading = false;
                for (var i = 0; i < result.length; i++)
                    galleryModel.append(result[i]);
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
        anchors.fill: parent
        clip: true
        model: galleryModel
        cacheBuffer: units.gu(40)

        delegate: GalleryCard {
            width: list.width
            post: galleryModel.get(index)
            onClicked: {
                var p = galleryModel.get(index);
                page.pageStack.push(Qt.resolvedUrl("PostDetailPage.qml"),
                    { author: p.author, permlink: p.permlink, title: p.caption });
            }
            onRequireLogin: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
        }

        footer: Item {
            width: list.width
            height: page.loading ? units.gu(6) : 0
            ActivityIndicator {
                anchors.centerIn: parent
                running: page.loading && galleryModel.count > 0
            }
        }

        onContentYChanged: {
            if (atYEnd && !page.loading && !page.endReached && galleryModel.count > 0)
                page.loadMore();
        }
    }

    LoadingState {
        anchors.fill: list
        visible: page.loading && galleryModel.count === 0
    }
    ErrorState {
        anchors.fill: list
        visible: page.errorMsg !== "" && galleryModel.count === 0
        message: page.errorMsg
        onRetry: page.reload()
    }
    EmptyState {
        anchors.fill: list
        visible: !page.loading && page.errorMsg === "" && galleryModel.count === 0
        iconName: "image-x-generic-symbolic"
        message: i18n.tr("No gallery posts in %1").arg(Config.communityName)
    }
}
