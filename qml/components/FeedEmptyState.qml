import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService
import "../services/VideoService.js" as VideoService
import "../services/HiddenPosts.js" as HiddenPosts

// My Feed empty state: offer subscriptions; relies on list-by-feed-mixed including them
Item {
    id: root

    // Emitted after a subscribe, so the feed can refetch.
    signal followed()
    // Carries the button so the community picker can anchor its dropdown to it on desktop.
    signal writePostRequested(var caller)
    // Card tapped outside the Subscribe pill: open that platform.
    signal communityRequested(var community)
    // A suggested article / video was tapped.
    signal postRequested(var post)
    signal videoRequested(var video)
    // A card's vote bar was used while logged out.
    signal loginRequested()

    // Three of each: enough to show what Serey is about, few enough that the
    // create-your-own-post action stays in reach on a phone screen.
    readonly property int maxSuggestions: 3
    readonly property int maxPosts: 3
    readonly property int maxVideos: 3

    property var suggestedPosts: []
    property var suggestedVideos: []
    // Blog and video in one list, newest first: the same mix list-by-feed-mixed serves
    // a reader who does have a feed. Videos carry _kind so the delegate can tell them apart.
    readonly property var suggestions: {
        var all = [];
        var i;
        for (i = 0; i < root.suggestedPosts.length; i++) all.push(root.suggestedPosts[i]);
        for (i = 0; i < root.suggestedVideos.length; i++) {
            var v = root.suggestedVideos[i];
            v._kind = "video";
            all.push(v);
        }
        all.sort(function (a, b) {
            return Date.parse(b.date || 0) - Date.parse(a.date || 0);
        });
        return all;
    }

    // > 0 = intro in a leading column of that width, cards in the pane beside it.
    property real leadingWidth: 0
    readonly property bool split: leadingWidth > 0

    // Fallback Tab stop (the create-post button) when there are no platform cards.
    property Item firstFocusItem: null

    // Called by FeedPage when keyboard nav lands on My Feed while this state is up:
    // focusing the hidden, empty feed list would look like the keyboard was dead.
    function focusFirst() {
        var it = (platforms.firstFocusItem && platforms.firstFocusItem.visible)
                 ? platforms.firstFocusItem : root.firstFocusItem;
        if (!it || !it.visible) return false;
        // Drop focus first: Qt skips focusInEvent (and the key-nav reason) if already focused.
        it.focus = false;
        it.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }

    // Readers with a feed never see this state, so nothing is fetched until it shows:
    // three requests on every My Feed open would only slow the feed down.
    property bool _loaded: false

    onVisibleChanged: if (visible && !root._loaded) root._load()

    function _load() {
        root._loaded = true;
        platforms.load();

        // Scoped to the reader's country first, like the platform picks; the header's
        // community can't stand in (the picker has no Cambodia row, so KH readers sit
        // on Global, which hides Cambodia). A country with nothing falls back to it.
        // community_id filters recursively, so a country covers its platforms too.
        var home = Config.homeCountryCommunityId;
        root._loadScoped(PostService.listTrending, root.maxPosts, home,
            function (posts) { root.suggestedPosts = posts; });
        root._loadScoped(VideoService.listVideos, root.maxVideos, home,
            function (videos) { root.suggestedVideos = videos; });
    }

    // One suggestion section: home country, else the header scope. Failures just hide it.
    function _loadScoped(fetch, limit, home, done) {
        function fallback() {
            fetch(Config.baseUrl, root._scopeParams(limit), Session.token,
                function (rows) { done(rows.slice(0, limit)); }, function () {});
        }
        if (!home) { fallback(); return; }
        fetch(Config.baseUrl, { limit: limit, offset: 0, community_id: home }, Session.token,
            function (rows) { if (rows.length) done(rows.slice(0, limit)); else fallback(); },
            fallback);
    }

    function _hideSuggestion(entry) {
        if (!entry) return;
        var permlink = entry.permlink || "";
        HiddenPosts.hide(permlink);
        PostActions.hideRequested(entry.author || "", permlink);
        function drop(list) {
            var out = [];
            for (var i = 0; i < list.length; i++)
                if ((list[i].permlink || "") !== permlink) out.push(list[i]);
            return out;
        }
        root.suggestedPosts = drop(root.suggestedPosts);
        root.suggestedVideos = drop(root.suggestedVideos);
    }

    function _shareSuggestion(entry, caller) {
        if (!entry) return;
        Share.open(entry._kind === "video"
            ? ("https://serey.io/video-component/watch?author=" + entry.author + "&permalink=" + entry.permlink)
            : ("https://serey.io/authors/" + entry.author + "/" + entry.permlink), caller);
    }

    function _followSuggestion(entry) {
        if (!entry || !entry.author || entry.author === Session.username) return;
        if (!Session.isLoggedIn) { Toast.error(Lang.tr("Please log in first.")); return; }
        var now = FollowStore.toggle(Config.baseUrl, entry.author, Session.token);
        Toast.show(now ? Lang.tr("Following") : Lang.tr("Unfollowed"));
    }

    // Fallback scope: the header's community, or the Global mix.
    function _scopeParams(limit) {
        var params = { limit: limit, offset: 0 };
        if (Config.communityId > 0) params.community_id = Config.communityId;
        else params.exclude_home = 1;   // Global hides the Cambodia community + children
        return params;
    }

    // Leading column (or the whole surface when narrow): intro + create action.
    Item {
        id: leadPane
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: root.split ? root.leadingWidth : root.width

        Flickable {
            id: flick
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: footer.top }
            contentWidth: width
            contentHeight: outer.height + Style.spacingL * 2
            clip: true

            Column {
                id: outer
                width: parent.width
                y: Style.spacingL
                spacing: Style.spacingL

                Column {
                    id: col
                    width: Math.min(parent.width - Style.spacingL * 2, units.gu(50))
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.spacingL

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(col.width * (root.split ? 0.7 : 0.5), units.gu(16))
                        height: width * (434 / 398)
                        source: Qt.resolvedUrl("../../assets/onboarding.svg")
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Column {
                        width: parent.width
                        spacing: Style.spacingXs
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Lang.tr("Your feed is empty")
                            font.pixelSize: Style.fontLarge
                            font.weight: Font.DemiBold
                            font.family: Style.fontFor(text)
                            color: Style.textTitle
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Lang.tr("Subscribe to a platform to fill it, or share the first post yourself.")
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFor(text)
                            color: Style.textSecondary
                            wrapMode: Text.WordWrap
                        }
                    }

                }

                // Host for the lists when there is no detail pane: the feed's own list width
                // (gu(60) cap, centred). Rows inset themselves, so dividers run full width.
                Item {
                    id: narrowHost
                    width: Math.min(parent.width, units.gu(60))
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: root.split ? 0 : discover.height
                    visible: !root.split
                }
            }
        }

        // Pinned so the create action stays reachable no matter how long the list is.
        Rectangle {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: footerBtn.height + Style.spacingM * 2
            color: Style.surface

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: units.dp(1); color: Style.divider
            }

            SecondaryButton {
                id: footerBtn
                anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.horizontalCenter }
                width: Math.min(parent.width - Style.spacingL * 2, units.gu(50))
                text: Lang.tr("Write your first post")
                onClicked: root.writePostRequested(footerBtn)

                KeyTapArea {
                    id: footerKeys
                    onActivated: root.writePostRequested(footerBtn)
                    // Nothing to subscribe to yet: this is then the only thing to focus.
                    Component.onCompleted: if (!root.firstFocusItem) root.firstFocusItem = this
                }
            }
        }
    }

    // Detail pane: the discover grid, opaque so it covers the "select a post" placeholder.
    Rectangle {
        id: discoverPane
        anchors { top: parent.top; bottom: parent.bottom; left: leadPane.right; right: parent.right }
        visible: root.split
        color: Style.surface

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: units.dp(1); color: Style.divider
        }

        Flickable {
            anchors { fill: parent; margins: Style.spacingL }
            contentWidth: width
            contentHeight: wideCol.height
            clip: true

            Column {
                id: wideCol
                width: parent.width
                spacing: Style.spacingM

                Column {
                    width: parent.width
                    spacing: Style.spacingXs
                    Label {
                        width: parent.width
                        text: Lang.tr("Discover platforms to follow")
                        font.pixelSize: Style.fontTitle
                        font.weight: Font.DemiBold
                        font.family: Style.fontFor(text)
                        color: Style.textTitle
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        text: Lang.tr("Subscribe to platforms to see their posts in your feed.")
                        font.pixelSize: Style.fontRegular
                        font.family: Style.fontFor(text)
                        color: Style.textSecondary
                        wrapMode: Text.WordWrap
                    }
                }

                Item {
                    id: wideHost
                    width: parent.width
                    height: root.split ? discover.height : 0
                }
            }
        }
    }

    // One discover column (platforms, then articles, then videos), hosted by
    // whichever pane is active - only one of the two is visible at a time.
    Column {
        id: discover
        parent: root.split ? wideHost : narrowHost
        width: parent ? parent.width : 0
        spacing: Style.spacingS

        // The wide pane already titles this list ("Discover platforms to follow").
        ListSectionHeader {
            visible: !root.split && (platforms.loading || platforms.suggested.length > 0)
            text: Lang.tr("Suggested platforms")
        }
        PlatformSuggestions {
            id: platforms
            width: parent.width
            maxSuggestions: root.maxSuggestions
            onSubscribed: root.followed()
            onCommunityRequested: root.communityRequested(community)
        }

        // Something to read and watch right now, mixed like a real feed.
        Column {
            width: parent.width
            spacing: 0
            visible: root.suggestions.length > 0

            ListSectionHeader { text: Lang.tr("Trending now") }

            // Rows sit flush like the feed's list: a gap between them would show the page
            // behind each card as soon as one is swiped.
            Column {
                width: parent.width
                spacing: 0

                Repeater {
                    model: root.suggestions

                    // Both card components live inside the delegate: loaded from outside it
                    // they could not see modelData (same reason FeedPage nests its two).
                    delegate: ListItem {
                        id: cardHost
                        width: discover.width
                        height: cardLoader.height
                        // Without these the row is transparent, so a swipe shows the page
                        // behind it and the toolkit's grey press highlight over the card.
                        color: Style.surface
                        highlightColor: Style.surface
                        divider.visible: false

                        readonly property var entry: modelData
                        readonly property bool isVideo: modelData && modelData._kind === "video"

                        onClicked: cardHost.isVideo ? root.videoRequested(cardHost.entry)
                                                    : root.postRequested(cardHost.entry)
                        onPressAndHold: PostActions.open(cardHost.entry, cardHost.isVideo ? "video" : "blog")

                        // Same split the feed uses: leading = negative (Hide), trailing = positive.
                        // Swipe is a touch affordance; desktop reaches these through the card menu.
                        leadingActions: Config.desktopMode ? null : hideActions
                        ListItemActions {
                            id: hideActions
                            delegate: Rectangle {
                                width: units.gu(7)
                                height: parent ? parent.height : units.gu(6)
                                color: Style.danger
                                Icon {
                                    anchors.centerIn: parent
                                    width: units.gu(2.5); height: width
                                    name: action.iconName
                                    color: "white"
                                }
                            }
                            actions: [
                                Action {
                                    iconName: "view-off"
                                    text: Lang.tr("Hide")
                                    onTriggered: root._hideSuggestion(cardHost.entry)
                                }
                            ]
                        }

                        trailingActions: Config.desktopMode ? null : shareActions
                        ListItemActions {
                            id: shareActions
                            delegate: Item {
                                width: units.gu(7)
                                height: parent ? parent.height : units.gu(6)
                                readonly property bool isFollowAction: action.iconName === "contact"
                                Icon {
                                    anchors.centerIn: parent
                                    width: units.gu(2.5); height: width
                                    name: action.iconName
                                    color: (parent.isFollowAction && cardHost.entry
                                            && FollowStore.isFollowing(cardHost.entry.author))
                                        ? Style.brand : Style.textPrimary
                                }
                            }
                            actions: [
                                Action {
                                    iconName: "contact"
                                    text: Lang.tr("Follow")
                                    onTriggered: root._followSuggestion(cardHost.entry)
                                },
                                Action {
                                    iconName: "share"
                                    text: Lang.tr("Share…")
                                    onTriggered: root._shareSuggestion(cardHost.entry, cardHost)
                                }
                            ]
                        }

                        Loader {
                            id: cardLoader
                            width: parent.width
                            height: item ? item.implicitHeight : 0
                            sourceComponent: cardHost.isVideo ? videoComp : postComp
                        }

                        Component {
                            id: postComp
                            PostCard {
                                width: cardLoader.width
                                post: cardHost.entry
                                onClicked: root.postRequested(cardHost.entry)
                                onAuthorClicked: root.postRequested(cardHost.entry)
                                onRequireLogin: root.loginRequested()
                                onMoreClicked: PostActions.open(cardHost.entry, "blog")
                            }
                        }

                        Component {
                            id: videoComp
                            VideoCard {
                                width: cardLoader.width
                                video: cardHost.entry
                                onClicked: root.videoRequested(cardHost.entry)
                                onAuthorClicked: root.videoRequested(cardHost.entry)
                                onMoreClicked: PostActions.open(cardHost.entry, "video")
                            }
                        }
                    }
                }
            }
        }
    }
}
