import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PostService.js" as PostService

/*
 * Blog: newest articles (list-by-new) with infinite scroll. Tapping opens the
 * full article in PostDetailPage.
 */
Page {
    id: page

    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property string errorMsg: ""

    header: PageHeader {
        title: i18n.tr("Blog")
        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18n.tr("Refresh")
                onTriggered: page.reload()
            }
        ]
    }

    ListModel { id: feedModel; dynamicRoles: true }

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
        PostService.listNew(Config.baseUrl, { limit: Config.pageSize, offset: page.offset }, Session.token,
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
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
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
            width: parent.width
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
        message: i18n.tr("No articles to show")
    }
}
