import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/CommunitySubscriberService.js" as SubscriberService
import "../services/PostService.js" as PostService

// Suggested platforms, same order as the web's My Feed (fe-serey-web FeedPage.js):
// the reader's country, then the US/UK hubs, then wherever posts are trending.
// Used by the empty My Feed and above a feed that already has posts. Rendered as a
// flat Lomiri list (like SettingsRow): no cards, full-width hairline dividers.
Column {
    id: root

    // After a subscribe, so the feed can refetch.
    signal subscribed()
    // Card tapped outside the Subscribe pill: open that platform.
    signal communityRequested(var community)

    property int maxSuggestions: 3
    readonly property var suggested: root._pickSuggestions()   // [{id, title, dns, icon, trending}]
    // Skeleton rows show while true; hosts reserve the space so nothing shifts.
    readonly property bool loading: root._loaded && !root._ready
    // First Tab stop: the first Subscribe pill.
    property Item firstFocusItem: null

    readonly property var fallbackCountryCodes: ["us", "gb"]
    property var subscribedMap: ({})
    property int subscribedRev: 0
    property var _trendCounts: ({})   // community id -> posts in the trending list
    property var _trendOrder: []      // community ids, first trending appearance first
    // Subscribed when loaded. Separate from subscribedMap so a card the reader just
    // subscribed to stays put and flips its pill instead of vanishing.
    property var _excludeMap: ({})
    property bool _subsLoaded: false
    // Trending answered (or failed, or trendCap gave up on it). Waiting for it keeps
    // the rows from appearing and then re-ordering when the counts land.
    property bool _trendDone: false
    readonly property bool _ready: root._subsLoaded && root._trendDone
    property bool _loaded: false

    Timer { id: trendCap; interval: 2500; onTriggered: root._trendDone = true }

    // Callers load on first show, so a hidden instance costs no requests.
    function load() {
        if (root._loaded) return;
        root._loaded = true;
        if (Session.isLoggedIn)
            SubscriberService.fetchSubscribed(Config.baseUrl, Session.token,
                function (map) {
                    root.subscribedMap = map; root._excludeMap = map;
                    root.subscribedRev++; root._subsLoaded = true;
                },
                function () { root._subsLoaded = true; /* rows just start unsubscribed */ });
        else
            root._subsLoaded = true;

        // Ranking signal only (the web uses the same 30), capped so a slow answer
        // can't hold the skeleton.
        trendCap.start();
        PostService.listTrending(Config.baseUrl, { limit: 30, offset: 0 }, Session.token,
            function (posts) {
                var counts = {};
                var order = [];
                for (var i = 0; i < posts.length; i++) {
                    var id = String(posts[i].communityId || "");
                    if (!id || id === "0") continue;
                    if (counts[id] === undefined) { counts[id] = 0; order.push(id); }
                    counts[id]++;
                }
                root._trendCounts = counts;
                root._trendOrder = order;
                root._trendDone = true;
            },
            function () { root._trendDone = true; /* country order still stands */ });
    }

    function _pickSuggestions() {
        // Without the subscription list we'd briefly offer platforms already joined.
        if (!root._ready) return [];
        var byId = Config.communityById;
        var counts = root._trendCounts;
        var kids = {};
        var parents = Config.parentCommunityById;
        for (var child in parents) (kids[parents[child]] = kids[parents[child]] || []).push(child);

        var picked = [];
        var seen = {};
        // allowHidden: only the reader's own country may surface the Global-hidden subtree.
        function add(id, allowHidden) {
            if (picked.length >= root.maxSuggestions || seen[id] || root._excludeMap[id]) return;
            var c = byId[id];
            if (!c || (!allowHidden && Config.hiddenCommunityIds[id])) return;
            seen[id] = true;
            picked.push({ id: c.id, title: c.title, dns: c.dns, icon: Config.communityIconFor(id),
                          trending: counts[id] || 0 });
        }
        // Busiest first; the tree's own order isn't kept, so ties go by id.
        function addCountry(countryId, allowHidden) {
            var list = (kids[countryId] || []).slice();
            list.sort(function (a, b) { return (counts[b] || 0) - (counts[a] || 0) || a - b; });
            for (var i = 0; i < list.length; i++) add(list[i], allowHidden);
        }

        addCountry(Config.homeCountryCommunityId, true);
        for (var f = 0; f < root.fallbackCountryCodes.length; f++)
            addCountry(Config.countryCommunityId(root.fallbackCountryCodes[f]), false);
        for (var k = 0; k < root._trendOrder.length; k++) add(root._trendOrder[k], false);
        return picked;
    }

    // Card subtitle: the platform's country, plus how busy it is right now.
    function cardMeta(item) {
        var parts = [];
        var parent = Config.communityById[Config.parentCommunityById[String(item.id)] || ""];
        if (parent && parent.title) parts.push(parent.title);
        if (item.trending === 1) parts.push(Lang.tr("1 trending post"));
        else if (item.trending > 1) parts.push(Lang.tr("%1 trending posts").arg(item.trending));
        return parts.join(" · ");
    }

    function _toggleSubscribe(commId, currentlySubscribed) {
        if (!Session.isLoggedIn) return;
        var id = String(commId);
        function newMap(add) {
            var m = {};
            for (var k in root.subscribedMap) m[k] = true;
            if (add) m[id] = true; else delete m[id];
            return m;
        }
        if (currentlySubscribed) {
            SubscriberService.unsubscribe(Config.baseUrl, Session.token, id,
                function () { root.subscribedMap = newMap(false); root.subscribedRev++; },
                function (err) { Toast.show(err.message || Lang.tr("Couldn't unsubscribe. Try again.")); });
        } else {
            SubscriberService.subscribe(Config.baseUrl, Session.token, id,
                function () { root.subscribedMap = newMap(true); root.subscribedRev++; root.subscribed(); },
                function (err) { Toast.show(err.message || Lang.tr("Couldn't subscribe. Try again.")); });
        }
    }

    // Same geometry as a real row, so the swap is in place.
    Repeater {
        model: root.loading ? root.maxSuggestions : 0

        delegate: Item {
            width: root.width
            height: units.gu(7)

            SkeletonRect {
                anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: units.gu(4.5); height: width; radius: width / 2
            }
            Column {
                anchors {
                    left: parent.left; leftMargin: Style.spacingM * 2 + units.gu(4.5)
                    verticalCenter: parent.verticalCenter
                }
                spacing: Style.spacingXs
                // Uneven widths read as text, not a grid of bars.
                SkeletonRect { width: units.gu(index === 1 ? 11 : 14); height: units.gu(1.8); radius: height / 2 }
                SkeletonRect { width: units.gu(8); height: units.gu(1.3); radius: height / 2 }
            }
            SkeletonRect {
                anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: units.gu(11); height: units.gu(3.5); radius: Style.pillRadius
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: units.dp(1)
                color: Style.divider
            }
        }
    }

    Repeater {
        model: root.suggested

        delegate: AbstractButton {
            id: row
            width: root.width
            height: units.gu(7)
            onClicked: root.communityRequested(modelData)
            // Fades in over the skeleton it replaces.
            NumberAnimation on opacity { from: 0; to: 1; duration: 200; easing.type: Easing.OutQuad }

            property string commId: String(modelData.id)
            property bool subscribed: root.subscribedRev >= 0 && !!root.subscribedMap[row.commId]


            Rectangle {
                anchors.fill: parent
                color: row.pressed ? Style.pressed : "transparent"
            }

            // Same circular logo the community picker uses for platforms.
            Rectangle {
                id: logo
                anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: units.gu(4.5); height: width; radius: width / 2
                color: Style.iconBackground
                CircleImage {
                    anchors { fill: parent; margins: units.dp(2) }
                    source: modelData.icon || ""
                    decode: units.gu(6)
                }
            }

            Column {
                id: texts
                anchors {
                    left: logo.right; leftMargin: Style.spacingM
                    right: pill.left; rightMargin: Style.spacingM
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.dp(2)

                Label {
                    width: parent.width
                    text: modelData.title
                    font.pixelSize: Style.fontRegular
                    font.family: Style.fontFor(text)
                    color: Style.textPrimary
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: root.cardMeta(modelData)
                    font.pixelSize: Style.fontSmall
                    font.family: Style.fontFor(text)
                    color: Style.textSecondary
                    elide: Text.ElideRight
                }
            }

            SubscribePill {
                id: pill
                anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: units.gu(11); height: units.gu(3.5)
                subscribed: row.subscribed
                onClicked: root._toggleSubscribe(row.commId, row.subscribed)

                KeyTapArea {
                    onActivated: root._toggleSubscribe(row.commId, row.subscribed)
                    Component.onCompleted: if (index === 0) root.firstFocusItem = this
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: units.dp(1)
                color: Style.divider
            }
        }
    }
}
