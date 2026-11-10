import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PodcastService.js" as PodcastService

Page {
    id: page

    readonly property real maxContentWidth: units.gu(60)

    property var episodes: []
    property var seasonList: []
    property int seasonIndex: 0
    property bool loading: false
    property string errorMsg: ""
    property int reqEpoch: 0
    property var inflight: null
    // background refresh: no spinner over the cached list
    property bool _quiet: false
    property string _inflightKey: ""
    // episode open in the detail pane
    property string openId: ""

    readonly property bool isGlobal: Config.communityId <= 0
    // Global and countries list the whole branch, like the web
    readonly property bool isAggregate: page.isGlobal || !!Config.topLevelCommunityIds[Config.communityId]
    readonly property var shown: {
        // Global hides Cambodia + its platforms, same as the other feeds
        if (page.isGlobal) return page.episodes.filter(function (e) { return !Config.hiddenCommunityIds[String(e.communityId)]; });
        if (page.seasonList.length < 2) return page.episodes;
        var s = page.seasonList[page.seasonIndex].number;
        return page.episodes.filter(function (e) { return e.seasonNumber === s; });
    }

    header: Item { height: 0 }

    // a hidden tab waits until it's shown, instead of fetching on every platform switch
    property bool stale: false
    Connections {
        target: Config
        function onCommunityIdChanged() {
            page.episodes = [];
            page.seasonList = [];
            if (page.visible) page.reload(); else page.stale = true;
        }
    }
    // back to the list clears the highlight
    Connections {
        target: page.pageStack
        ignoreUnknownSignals: true
        function onCurrentPageChanged() { if (page.pageStack.currentPage === page) page.openId = ""; }
    }
    Connections {
        target: Net
        function onOnlineChanged() { if (Net.online && page.episodes.length === 0) page.reload(); }
    }

    function reload(pulled) {
        page._quiet = !pulled;
        page.stale = false;
        page.reqEpoch++;
        var epoch = page.reqEpoch;
        page.loading = true;
        // last list paints at once, fetch replaces it
        var key = FeedCache.podcastKey(Config.communityId);
        // a refresh of the same list joins the shared request; only a platform switch drops the old one
        if (inflight && page._inflightKey !== key) inflight.abort();
        inflight = null;
        page._inflightKey = key;
        if (page.episodes.length === 0) page.episodes = FeedCache.peek(key) || [];
        page.errorMsg = "";
        var started = Date.now();
        var ok = function (rows) {
            if (epoch !== page.reqEpoch) return;
            Player.log("list " + key + " loaded in " + (Date.now() - started) + "ms, " + rows.length + " rows");
            inflight = null;
            page.loading = false;
            // platform name for the publisher line
            if (!page.isAggregate) rows.forEach(function (r) { if (!r.communityTitle) r.communityTitle = Config.currentCommunityName; });
            page.episodes = rows;
            // stay on the same season after an edit or delete
            var keep = page.seasonList.length > page.seasonIndex ? page.seasonList[page.seasonIndex].number : -1;
            var seasons = page.isAggregate ? [] : PodcastService.seasons(rows);
            page.seasonIndex = 0;
            page.seasonList = seasons;
            page.seasonIndex = Math.max(0, seasons.map(function (x) { return x.number; }).indexOf(keep));
        };
        var err = function (e) {
            if (epoch !== page.reqEpoch) return;
            inflight = null;
            page.loading = false;
            page.errorMsg = e.message;
        };
        // joins the launch prefetch when it's still in flight instead of fetching twice
        var cid = Config.communityId, agg = page.isAggregate;
        inflight = FeedCache.request(key, function (o, e) { return PodcastService.listFor(Config.baseUrl, cid, agg, o, e); }, ok, err);
    }

    function open(ep) {
        page.openId = String(ep.id);
        var p = page.pageStack.push(Qt.resolvedUrl("PodcastEpisodePage.qml"), { episode: ep, queue: page.shown });
        if (p && p.changed) p.changed.connect(page.reload);
        // follow autoplay to the next episode
        if (p) p.episodeChanged.connect(function () { if (p.episode) page.openId = String(p.episode.id); });
    }
    // header add button
    function compose() {
        var p = page.pageStack.push(Qt.resolvedUrl("CreatePodcastEpisodePage.qml"),
                                    { defaultSeason: page.seasonList.length ? page.seasonList[page.seasonIndex].number : 1 });
        if (p && p.saved) p.saved.connect(page.reload);
    }

    Component.onCompleted: reload()

    property Item keyboardFocusItem: list
    onVisibleChanged: if (visible) { if (page.stale) page.reload(); list.forceActiveFocus(); }

    SectionTabs {
        id: tabs
        anchors { left: parent.left; right: parent.right; top: parent.top }
        visible: page.seasonList.length > 1
        height: visible ? implicitHeight : 0
        model: page.seasonList.map(function (s) {
            return s.title ? s.title : Lang.tr("Season") + " " + s.number;
        })
        currentIndex: page.seasonIndex
        onSelected: page.seasonIndex = index
        onFocusList: list.forceActiveFocus()
    }

    ListView {
        id: list
        anchors { top: tabs.bottom; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width, page.maxContentWidth)
        clip: true
        model: page.shown
        Keys.onLeftPressed: Nav.focusNav()

        // only for a real pull: running it for background reloads left the header scrolled out of view
        PullToRefresh {
            refreshing: page.loading && page.shown.length > 0 && !page._quiet
            // a pull during a quiet refresh adopts it
            onRefresh: if (page.loading) page._quiet = false; else page.reload(true)
        }

        header: Item {
            width: list.width
            height: headerLabel.height + Style.spacingM + Style.spacingS
            Label {
                id: headerLabel
                x: Style.spacingM
                y: Style.spacingM
                text: page.isAggregate ? Lang.tr("Latest Episodes") : Lang.tr("Episodes")
                font.pixelSize: Style.fontMedium
                font.weight: Font.DemiBold
                color: Style.textPrimary
            }
        }

        delegate: ListItem {
            width: list.width
            height: row.height + Style.spacingM * 2
            color: (Config.wideMode && page.openId === String(modelData.id)) ? Style.iconBackground : Style.surface
            divider.colorFrom: Style.divider
            divider.colorTo: Style.divider
            onClicked: page.open(modelData)

            EpisodeRow {
                id: row
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                episode: modelData
                showSeason: page.isAggregate
            }
        }

        footer: Item { width: list.width; height: units.gu(6) }
    }

    LoadingState {
        anchors.fill: list
        variant: "episode"
        count: 8
        // covers the cached list while fetching; a pull keeps its spinner
        visible: page.loading && (page.shown.length === 0 || page._quiet)
    }

    ErrorState {
        anchors.fill: list
        visible: page.errorMsg !== "" && page.shown.length === 0
        message: page.errorMsg
        onRetry: page.reload()
    }

    EmptyState {
        anchors.fill: list
        visible: !page.loading && page.errorMsg === "" && page.shown.length === 0
        iconName: "audio-input-microphone-symbolic"
        message: Lang.tr("No episodes to show")
    }
}
