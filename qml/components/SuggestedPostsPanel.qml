import QtQuick 2.7
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService
import "../services/HiddenPosts.js" as HiddenPosts
import "../services/BlockedUsers.js" as BlockedUsers
import "../services/Notes.js" as Notes

// Wide-window detail placeholder: featured row + paged carousel (web homepage style)
Rectangle {
    id: root

    signal postRequested(var post)

    color: Style.surface

    // Layout by pane width
    readonly property bool roomy: width >= units.gu(100)
    readonly property int featuredCount: roomy ? 2 : 1
    readonly property int perPage: roomy ? 3 : 2
    readonly property int notesPerPage: perPage
    // Notes row inset from blog edges
    readonly property real notesInset: roomy ? units.gu(10) : units.gu(4)
    // A short briefing: 5 to 8 posts, not a second feed
    readonly property int maxPages: 2
    readonly property int minPosts: 3
    readonly property int maxPerAuthor: 2
    readonly property real gap: Style.spacingM
    // Wider gutters, content capped
    readonly property real maxContentW: units.gu(130)
    readonly property real sidePad: Math.max(units.gu(9), (width - maxContentW) / 2)

    // Decode at real pixels, snapped to avoid re-decode per resize
    function decodePx(logical) {
        var step = units.gu(20);
        return Math.ceil(logical * Screen.devicePixelRatio / step) * step;
    }

    // Plain copies of the reader's own feed rows, handed in by FeedPage
    property var feedRows: []
    // True until the feed's first batch has landed
    property bool feedLoading: true
    // Pulled from FeedPage's last successful sync
    property var updatedAt: 0

    // Rows hidden/blocked while this panel is open
    property var droppedPermlinks: ({})
    property var droppedAuthors: ({})

    // Thin feed (follows little): topped up with country trending
    property var trending: []
    property bool trendingLoading: false
    property bool _trendingAsked: false

    // Imperative, not bound: a refresh used to rebuild every card and flip the pagers
    // through empty states. _refresh() only swaps a list when its members really change.
    property var posts: []
    property var notes: []
    property bool thin: false
    property bool loading: true
    readonly property bool notesLoading: root.loading
    readonly property int notePages: Math.ceil(Math.min(notes.length, notesPerPage * maxPages) / notesPerPage)
    // Notes need a few to look like a row
    readonly property bool showNotes: root.notes.length >= 3

    readonly property var featured: posts.slice(0, featuredCount)
    readonly property var rest: posts.slice(featuredCount, featuredCount + perPage * maxPages)
    readonly property int pageCount: Math.ceil(rest.length / perPage)

    function _isMedia(p) {
        var c = p.categories || [];
        if (p.primaryCategory === "video" || p.primaryCategory === "gallery") return true;
        return !!(c.indexOf && (c.indexOf("video") >= 0 || c.indexOf("gallery") >= 0));
    }

    function _allowed(p) {
        return !!p && !!p.permlink && !root._isMedia(p)
            && !HiddenPosts.loadAll()[p.permlink] && !BlockedUsers.loadAll()[p.author || ""];
    }

    // HTML entities in titles
    function _decode(s) {
        return String(s || "")
            .replace(/&#(\d+);/g, function (m, n) { return String.fromCharCode(+n); })
            .replace(/&quot;/g, "\"").replace(/&apos;/g, "'")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
    }

    function _score(p) {
        var payout = parseFloat(String(p.payout || ""));
        if (isNaN(payout)) payout = 0;
        var t = Date.parse(p.date || "");
        var ageH = isNaN(t) ? 72 : Math.max(0, (Date.now() - t) / 3600000);
        var s = ((p.votes || 0) + (p.comments || 0) * 2 + Math.log(1 + payout) * 2 + 1) / (1 + ageH / 24);
        return (p.thumbnail || "") !== "" ? s * 1.25 : s;
    }

    function _usable(p) {
        return root._allowed(p) && !root.droppedPermlinks[p.permlink] && !root.droppedAuthors[p.author || ""];
    }

    // The reader's own feed, most important first; photos win ties, one author can't fill the page
    function _rank(rows) {
        var scored = [];
        for (var i = 0; i < rows.length; i++) {
            var p = rows[i];
            if (p.isNote || p._kind === "video" || !root._usable(p)) continue;
            scored.push({ post: p, score: root._score(p) });
        }
        scored.sort(function (a, b) { return b.score - a.score; });
        var want = root.featuredCount + root.perPage * root.maxPages;
        var perAuthor = {}, out = [];
        for (var j = 0; j < scored.length && out.length < want; j++) {
            var q = scored[j].post, a = q.author || "";
            if ((perAuthor[a] || 0) >= root.maxPerAuthor) continue;
            perAuthor[a] = (perAuthor[a] || 0) + 1;
            q.title = root._decode(q.title);
            out.push(q);
        }
        return out;
    }

    function _feedNotes(rows) {
        var out = [];
        for (var i = 0; i < rows.length && out.length < root.notesPerPage * root.maxPages; i++)
            if (rows[i].isNote && root._usable(rows[i])) out.push(rows[i]);
        return out;
    }

    // Follows little: fill with trending, never repeating a feed post
    function _topUp(own, extra) {
        var seen = {}, out = own.slice();
        for (var i = 0; i < out.length; i++) seen[out[i].permlink] = true;
        var want = root.featuredCount + root.perPage * root.maxPages;
        for (var j = 0; j < extra.length && out.length < want; j++) {
            if (seen[extra[j].permlink] || !root._usable(extra[j])) continue;
            out.push(extra[j]);
        }
        return out;
    }

    // Home country first, then header scope
    function _scoped(fetch, limit, done, fail) {
        function fallback() {
            var params = { limit: limit, offset: 0 };
            if (Config.communityId > 0) params.community_id = Config.communityId;
            else params.exclude_home = 1;
            fetch(Config.baseUrl, params, Session.token, done, fail);
        }
        var home = Config.homeCountryCommunityId;
        if (!home) { fallback(); return; }
        fetch(Config.baseUrl, { limit: limit, offset: 0, community_id: home }, Session.token,
            function (rows) { if (rows.length) done(rows); else fallback(); }, fallback);
    }

    function _loadTrending() {
        root._trendingAsked = true;
        root.trendingLoading = true;
        // Callbacks can land after My Feed closed and destroyed us
        root._scoped(PostService.listTrending, 20, function (rows) {
            if (!root) return;
            var out = [];
            for (var i = 0; i < rows.length; i++)
                if (!rows[i].isNote && root._allowed(rows[i])) {
                    rows[i].title = root._decode(rows[i].title);
                    out.push(rows[i]);
                }
            root.trending = out;
            root.trendingLoading = false;
        }, function () { if (root) root.trendingLoading = false; });
    }

    function _members(list) {
        return list.map(function (p) { return p.permlink; }).sort().join(",");
    }

    // Same posts as on screen: keep the current order and objects (no card swaps)
    function _keep(cur, next) {
        return cur.length === next.length && root._members(cur) === root._members(next);
    }

    function _refresh() {
        if (root.feedLoading) return;
        var r = root._rank(root.feedRows);
        var isThin = r.length < root.minPosts;
        var p = isThin ? root._topUp(r, root.trending) : r;
        var n = root._feedNotes(root.feedRows);
        if (isThin !== root.thin) root.thin = isThin;
        if (isThin && !root._trendingAsked) root._loadTrending();
        if (!root._keep(root.posts, p)) root.posts = p;
        if (!root._keep(root.notes, n)) root.notes = n;
        // A thin feed with trending still on its way keeps the skeleton, not an empty pane
        var wait = isThin && root.trendingLoading && p.length === 0;
        if (root.loading !== wait) root.loading = wait;
    }

    onFeedRowsChanged: root._refresh()
    onFeedLoadingChanged: root._refresh()
    onDroppedPermlinksChanged: root._refresh()
    onDroppedAuthorsChanged: root._refresh()
    onTrendingChanged: root._refresh()
    onTrendingLoadingChanged: root._refresh()
    // First data in: start at the heading, not wherever the empty pane was left
    onLoadingChanged: if (!root.loading && !flick.moving) flick.contentY = 0

    // Same as the blog card's platform tag
    function openPlatform(p) {
        var cid = (p && p.communityId) || 0;
        var info = cid > 0 ? Config.communityInfoFor(cid) : null;
        if (!info) return;
        Nav.filterCategory("", {
            id: cid,
            name: info.title || info.name || "",
            icon: info.icon || "",
            allowPost: !!info.allowPost,
            videoAllowPost: !!info.videoAllowPost
        });
    }

    Component.onCompleted: root._refresh()

    Connections {
        target: PostActions
        function _drop(permlink) {
            var d = {};
            for (var k in root.droppedPermlinks) d[k] = true;
            d[permlink] = true;
            root.droppedPermlinks = d;
        }
        function onHideRequested(author, permlink) { _drop(permlink); }
        function onPostDeleted(author, permlink) { _drop(permlink); }
        function onUserBlocked(username) {
            var d = {};
            for (var k in root.droppedAuthors) d[k] = true;
            d[username] = true;
            root.droppedAuthors = d;
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height + Style.spacingL * 2
        clip: true

        Column {
            id: col
            y: Style.spacingL
            x: root.sidePad
            width: root.width - root.sidePad * 2
            spacing: Style.spacingL

            Label {
                text: root.thin ? Lang.tr("Trending on Serey") : Lang.tr("Your briefing")
                font.pixelSize: Style.fontLarge
                font.weight: Font.DemiBold
                font.family: Style.fontFor(text)
                color: Style.textTitle
            }

            Label {
                visible: root.updatedAt > 0 && !root.thin
                text: Lang.tr("Updated") + " " + Style.formatTimeAgo(new Date(root.updatedAt).toISOString())
                font.pixelSize: Style.fontXSmall
                color: Style.textSecondary
            }

            // Featured: text over image
            Row {
                id: featuredRow
                width: parent.width
                spacing: root.gap
                readonly property real cardW: (width - spacing * (root.featuredCount - 1)) / root.featuredCount

                Repeater {
                    model: root.loading ? root.featuredCount : root.featured
                    delegate: Item {
                        id: big
                        readonly property var post: root.loading ? ({}) : modelData
                        width: featuredRow.cardW
                        height: Math.round(width * 0.62)

                        SkeletonRect {
                            anchors.fill: parent
                            radius: Style.thumbRadius * 1.5
                            loading: root.loading
                        }

                        Item {
                            anchors.fill: parent
                            visible: !root.loading

                            RoundedThumb {
                                anchors.fill: parent
                                radius: Style.thumbRadius * 1.5
                                decodeWidth: root.decodePx(featuredRow.cardW)
                                decodeHeight: root.decodePx(featuredRow.cardW * 0.62)
                                mipmap: true
                                source: big.post.thumbnail || Qt.resolvedUrl("../../assets/thumbnail-fallback.png")
                            }
                            // Bottom scrim
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: parent.height * 0.6
                                radius: Style.thumbRadius * 1.5
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                                }
                            }
                            // Hover lift, no resampling
                            Rectangle {
                                anchors.fill: parent
                                radius: Style.thumbRadius * 1.5
                                color: "white"
                                opacity: bigMouse.containsMouse ? 0.06 : 0
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }
                            PostCornerTags {
                                anchors { top: parent.top; right: parent.right; margins: Style.spacingS }
                                z: 1
                                post: big.post
                                onPlatformClicked: root.openPlatform(big.post)
                            }
                            Column {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Style.spacingM }
                                spacing: Style.spacingS
                                Label {
                                    width: parent.width
                                    text: big.post.title || ""
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    font.pixelSize: root.roomy ? Style.fontLarge : Style.fontMedium
                                    font.weight: Font.Bold
                                    font.family: Style.fontFor(text)
                                    color: "white"
                                }
                                Row {
                                    spacing: Style.spacingS
                                    ReporterAvatar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: units.gu(2.6)
                                        name: (big.post && big.post.author) || ""
                                        source: (big.post && big.post.authorImage) || ""
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (big.post && big.post.author) || ""
                                        font.pixelSize: Style.fontSmall
                                        font.weight: Font.DemiBold
                                        color: "white"
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: bigMouse
                            // Under the tags
                            z: -1
                            anchors.fill: parent
                            enabled: !root.loading
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.postRequested(big.post)
                            onPressAndHold: PostActions.open(big.post, "blog")
                        }
                        KeyTapArea { enabled: !root.loading; onActivated: root.postRequested(big.post) }
                    }
                }
            }

            // Carousel: perPage cards a page
            Item {
                id: carousel
                width: parent.width
                height: pager.height
                visible: root.loading || root.pageCount > 0
                readonly property real cardW: (width - root.gap * (root.perPage - 1)) / root.perPage
                readonly property real cardH: Math.round(cardW * 0.62) + units.gu(10)

                Item {
                    id: pager
                    width: parent.width
                    height: carousel.cardH
                    property int currentIndex: 0
                    // Clamped, so a re-rank that drops a page can never leave a blank one showing
                    readonly property int page: Math.min(currentIndex, Math.max(0, root.pageCount - 1))
                    onPageChanged: pagerFade.restart()
                    NumberAnimation { id: pagerFade; target: pageRow; property: "opacity"; from: 0; to: 1; duration: 200 }
                    Row {
                        id: pageRow
                        readonly property int pageIndex: pager.page
                        width: pager.width
                        height: pager.height
                        spacing: root.gap

                        Repeater {
                            model: root.perPage
                            delegate: Item {
                                id: small
                                readonly property int idx: pageRow.pageIndex * root.perPage + index
                                readonly property var post: root.loading ? ({}) : (root.rest[idx] || null)
                                width: carousel.cardW
                                height: carousel.cardH
                                visible: root.loading || !!post

                                Column {
                                    width: parent.width
                                    spacing: Style.spacingS

                                    Item {
                                        width: parent.width
                                        height: Math.round(width * 0.62)
                                        SkeletonRect {
                                            anchors.fill: parent
                                            radius: Style.thumbRadius * 1.5
                                            loading: root.loading
                                        }
                                        RoundedThumb {
                                            anchors.fill: parent
                                            visible: !root.loading
                                            radius: Style.thumbRadius * 1.5
                                            decodeWidth: root.decodePx(carousel.cardW)
                                            decodeHeight: root.decodePx(carousel.cardW * 0.62)
                                            mipmap: true
                                            source: (small.post && small.post.thumbnail) || Qt.resolvedUrl("../../assets/thumbnail-fallback.png")
                                        }
                                        PostCornerTags {
                                            anchors { top: parent.top; right: parent.right; margins: Style.spacingS }
                                            visible: !root.loading && !!small.post
                                            z: 1
                                            post: small.post
                                            onPlatformClicked: root.openPlatform(small.post)
                                        }
                                    }
                                    Label {
                                        width: parent.width
                                        visible: !root.loading
                                        height: units.gu(5)
                                        text: (small.post && small.post.title) || ""
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        font.pixelSize: Style.fontRegular
                                        font.weight: Font.DemiBold
                                        font.family: Style.fontFor(text)
                                        color: smallMouse.containsMouse ? Style.brand : Style.textTitle
                                    }
                                    SkeletonRect {
                                        visible: root.loading
                                        width: parent.width * 0.8; height: units.gu(2)
                                    }
                                    Row {
                                        visible: !root.loading
                                        spacing: Style.spacingS
                                        ReporterAvatar {
                                            anchors.verticalCenter: parent.verticalCenter
                                            size: units.gu(2.6)
                                            name: (small.post && small.post.author) || ""
                                            source: (small.post && small.post.authorImage) || ""
                                        }
                                        Label {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (small.post && small.post.author) || ""
                                            font.pixelSize: Style.fontSmall
                                            font.weight: Font.DemiBold
                                            color: Style.textPrimary
                                        }
                                    }
                                }

                                MouseArea {
                                    id: smallMouse
                                    // Under the tags
                                    z: -1
                                    anchors.fill: parent
                                    enabled: !root.loading && !!small.post
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.postRequested(small.post)
                                    onPressAndHold: PostActions.open(small.post, "blog")
                                }
                                KeyTapArea {
                                    enabled: !root.loading && !!small.post
                                    onActivated: root.postRequested(small.post)
                                    onFocusChanged: if (focus) pager.currentIndex = pageRow.pageIndex
                                }
                            }
                        }
                    }
                }

                // Prev / next arrows
                Repeater {
                    model: [-1, 1]
                    delegate: AbstractButton {
                        readonly property bool canGo: modelData < 0 ? pager.page > 0
                                                                     : pager.page < root.pageCount - 1
                        visible: !root.loading && root.pageCount > 1
                        enabled: canGo
                        opacity: canGo ? 1 : 0.35
                        width: units.gu(4); height: width
                        x: modelData < 0 ? -width - units.gu(0.5) : carousel.width + units.gu(0.5)
                        y: Math.round(carousel.cardW * 0.62 / 2 - height / 2)
                        onClicked: pager.currentIndex = pager.page + modelData
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.4); height: width
                            name: modelData < 0 ? "go-previous" : "go-next"
                            color: Style.textPrimary
                        }
                    }
                }
            }

            // Page dots
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(0.75)
                visible: !root.loading && root.pageCount > 1
                Repeater {
                    model: root.pageCount
                    delegate: Rectangle {
                        readonly property bool on: index === pager.page
                        width: on ? units.gu(2.5) : units.gu(1)
                        height: units.gu(1)
                        radius: height / 2
                        color: on ? Style.textSecondary : Style.dotInactive
                        Behavior on width { NumberAnimation { duration: 200 } }
                        MouseArea {
                            anchors { fill: parent; margins: -units.gu(0.5) }
                            onClicked: pager.currentIndex = index
                        }
                    }
                }
            }

            // Suggested notes (wide only)
            Label {
                visible: root.notesLoading || root.showNotes
                x: noteCarousel.x
                text: Lang.tr("Latest notes")
                font.pixelSize: Style.fontLarge
                font.weight: Font.DemiBold
                font.family: Style.fontFor(text)
                color: Style.textTitle
            }

            Item {
                id: noteCarousel
                x: root.notesInset
                width: parent.width - root.notesInset * 2
                height: notePager.height
                visible: root.notesLoading || root.showNotes
                readonly property real cardW: (width - root.gap * (root.notesPerPage - 1)) / root.notesPerPage
                readonly property real pad: units.gu(1.25)
                // Header + 4 text lines + image
                readonly property real cardH: Math.round(pad * 2 + units.gu(3.5) + Style.spacingS * 2
                                                         + noteLine.height * 4 + (cardW - pad * 2) * 0.6)
                FontMetrics { id: noteLine; font.pixelSize: Style.fontRegular }

                Item {
                    id: notePager
                    width: parent.width + units.gu(1)
                    height: noteCarousel.cardH
                    property int currentIndex: 0
                    // Clamped, so a re-rank that drops a page can never leave a blank one showing
                    readonly property int page: Math.min(currentIndex, Math.max(0, root.notePages - 1))
                    onPageChanged: notePagerFade.restart()
                    NumberAnimation { id: notePagerFade; target: notePage; property: "opacity"; from: 0; to: 1; duration: 200 }
                    Row {
                        id: notePage
                        readonly property int pageIndex: notePager.page
                        width: notePager.width
                        height: notePager.height
                        spacing: root.gap

                        Repeater {
                            model: root.notesPerPage
                            delegate: Rectangle {
                                id: noteCard
                                readonly property int idx: notePage.pageIndex * root.notesPerPage + index
                                readonly property var post: root.notesLoading ? null : (root.notes[idx] || null)
                                readonly property string media: post ? (post.thumbnail || Notes.videoThumb(post.noteVideo || "")) : ""
                                readonly property bool bareVideo: !!post && media === "" && (post.noteVideo || "") !== ""
                                readonly property bool hasMedia: media !== "" || bareVideo
                                width: noteCarousel.cardW
                                height: noteCarousel.cardH
                                visible: root.notesLoading || !!post
                                radius: units.gu(1)
                                color: Style.noteCard
                                border.width: units.dp(1)
                                border.color: noteMouse.containsMouse ? Style.noteAccent : Style.noteCardBorder
                                readonly property bool isBreaking: !!post && /breaking/i.test(post.primaryCategory || "")

                                // Breaking ribbon: top-right, fold past card edge
                                BreakingRibbon {
                                    id: noteRibbon
                                    z: 2
                                    visible: noteCard.isBreaking
                                    bannerHeight: units.gu(2.6)
                                    anchors { right: parent.right; rightMargin: -fold }
                                    y: noteCarousel.pad + (units.gu(3.5) - height) / 2
                                }

                                MouseArea {
                                    id: noteMouse
                                    anchors.fill: parent
                                    enabled: !!noteCard.post
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.postRequested(noteCard.post)
                                    onPressAndHold: PostActions.open(noteCard.post, "blog")
                                }
                                KeyTapArea {
                                    enabled: !!noteCard.post
                                    onActivated: root.postRequested(noteCard.post)
                                    onFocusChanged: if (focus) notePager.currentIndex = notePage.pageIndex
                                }

                                SkeletonRect {
                                    anchors { fill: parent; margins: noteCarousel.pad }
                                    loading: root.notesLoading
                                }

                                Item {
                                    anchors { fill: parent; margins: noteCarousel.pad }
                                    visible: !!noteCard.post

                                    // Author + time
                                    Row {
                                        id: noteHead
                                        width: parent.width - noteBadge.width - noteBadge.anchors.rightMargin - Style.spacingS
                                        spacing: Style.spacingS
                                        ReporterAvatar {
                                            anchors.verticalCenter: parent.verticalCenter
                                            size: units.gu(3.5)
                                            name: (noteCard.post && noteCard.post.author) || ""
                                            source: (noteCard.post && noteCard.post.authorImage) || ""
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: noteHead.width - units.gu(3.5) - Style.spacingS
                                            Label {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: (noteCard.post && noteCard.post.author) || ""
                                                font.pixelSize: Style.fontSmall
                                                font.weight: Font.DemiBold
                                                color: Style.textTitle
                                            }
                                            Label {
                                                text: Style.formatTimeAgo((noteCard.post && noteCard.post.date) || "")
                                                font.pixelSize: Style.fontXSmall
                                                color: Style.textSecondary
                                            }
                                        }
                                    }
                                    // Note tag (as feed card)
                                    Rectangle {
                                        id: noteBadge
                                        // Left of ribbon when breaking
                                        anchors { right: parent.right; verticalCenter: noteHead.verticalCenter
                                                  rightMargin: noteCard.isBreaking ? noteRibbon.width - noteRibbon.fold - noteCarousel.pad + Style.spacingS : 0 }
                                        width: noteBadgeLabel.width + Style.spacingM
                                        height: units.gu(2.6)
                                        radius: Style.pillRadius
                                        color: "transparent"
                                        border.width: units.dp(1)
                                        border.color: Style.positive
                                        Label {
                                            id: noteBadgeLabel
                                            anchors.centerIn: parent
                                            text: Lang.tr("Note")
                                            font.pixelSize: Style.fontXSmall
                                            font.weight: Font.DemiBold
                                            font.family: Style.fontFor(text)
                                            color: Style.positive
                                        }
                                    }
                                    PostCornerTags {
                                        id: noteTags
                                        hideRibbon: true
                                        // Bottom-right, over media
                                        z: 1
                                        anchors { bottom: parent.bottom; right: parent.right; margins: noteCard.hasMedia ? Style.spacingS : 0 }
                                        post: noteCard.post
                                        onPlatformClicked: root.openPlatform(noteCard.post)
                                    }

                                    Label {
                                        id: noteBody
                                        anchors { top: noteHead.bottom; topMargin: Style.spacingS; left: parent.left; right: parent.right }
                                        text: (noteCard.post && noteCard.post.noteText) || ""
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: noteCard.hasMedia ? 4 : 9
                                        elide: Text.ElideRight
                                        font.pixelSize: Style.fontRegular
                                        font.family: Style.fontFor(text)
                                        color: Style.textPrimary
                                    }

                                    Item {
                                        anchors { top: noteBody.bottom; topMargin: Style.spacingS; left: parent.left; right: parent.right; bottom: parent.bottom }
                                        visible: noteCard.hasMedia
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: noteCard.bareVideo
                                            radius: Style.thumbRadius
                                            color: "black"
                                        }
                                        RoundedThumb {
                                            anchors.fill: parent
                                            visible: noteCard.media !== ""
                                            source: noteCard.media
                                            decodeWidth: root.decodePx(noteCarousel.cardW)
                                            decodeHeight: root.decodePx(noteCarousel.cardW * 0.6)
                                            mipmap: true
                                        }
                                        // Video marker
                                        Rectangle {
                                            visible: !!noteCard.post && (noteCard.post.noteVideo || "") !== ""
                                            anchors.centerIn: parent
                                            width: units.gu(5); height: width
                                            radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.55)
                                            Icon {
                                                anchors.centerIn: parent
                                                width: units.gu(2.5); height: width
                                                name: "media-playback-start"
                                                color: "white"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Prev / next arrows
                Repeater {
                    model: [-1, 1]
                    delegate: AbstractButton {
                        readonly property bool canGo: modelData < 0 ? notePager.page > 0
                                                                     : notePager.page < root.notePages - 1
                        visible: !root.notesLoading && root.notePages > 1
                        enabled: canGo
                        opacity: canGo ? 1 : 0.35
                        width: units.gu(4); height: width
                        x: modelData < 0 ? -width - units.gu(0.5) : noteCarousel.width + units.gu(0.5)
                        y: Math.round(noteCarousel.height / 2 - height / 2)
                        onClicked: notePager.currentIndex = notePager.page + modelData
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.4); height: width
                            name: modelData < 0 ? "go-previous" : "go-next"
                            color: Style.textPrimary
                        }
                    }
                }
            }

            // Note page dots
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(0.75)
                visible: !root.notesLoading && root.notePages > 1
                Repeater {
                    model: root.notePages
                    delegate: Rectangle {
                        readonly property bool on: index === notePager.page
                        width: on ? units.gu(2.5) : units.gu(1)
                        height: units.gu(1)
                        radius: height / 2
                        color: on ? Style.textSecondary : Style.dotInactive
                        Behavior on width { NumberAnimation { duration: 200 } }
                        MouseArea {
                            anchors { fill: parent; margins: -units.gu(0.5) }
                            onClicked: notePager.currentIndex = index
                        }
                    }
                }
            }

            Label {
                visible: !root.loading && root.posts.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Lang.tr("Select a post to read")
                color: Style.textSecondary
            }
        }
    }
}
