import QtQuick 2.7
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService
import "../services/HiddenPosts.js" as HiddenPosts
import "../services/BlockedUsers.js" as BlockedUsers
import "../services/Notes.js" as Notes
import "../services/NavPerf.js" as NavPerf

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
    readonly property int maxPages: 3
    readonly property real gap: Style.spacingM
    // Wider gutters, content capped
    readonly property real maxContentW: units.gu(130)
    readonly property real sidePad: Math.max(units.gu(9), (width - maxContentW) / 2)

    // Decode at real pixels, snapped to avoid re-decode per resize
    function decodePx(logical) {
        var step = units.gu(20);
        return Math.ceil(logical * Screen.devicePixelRatio / step) * step;
    }

    property var posts: []
    property var notes: []
    property bool loading: true
    property bool notesLoading: true
    readonly property int notePages: Math.ceil(Math.min(notes.length, notesPerPage * maxPages) / notesPerPage)

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

    // Articles, photos first
    function _pickPosts(rows) {
        var withImg = [], noImg = [];
        for (var i = 0; i < rows.length; i++) {
            var p = rows[i];
            if (p.isNote || !root._allowed(p)) continue;
            p.title = root._decode(p.title);
            ((p.thumbnail || "") !== "" ? withImg : noImg).push(p);
        }
        return withImg.concat(noImg);
    }

    function _pickNotes(rows) {
        return rows.filter(function (p) { return p.isNote && root._allowed(p); });
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

    // Last lists shown, so reopening My Feed paints at once; the fetch below refreshes them
    function _cacheKey(kind) {
        return "suggested:" + kind + ":" + (Config.homeCountryCommunityId || "0") + ":" + Config.communityId
               + ":" + (Session.username || "__guest__");
    }
    function _sig(list) { return list.map(function (p) { return p.permlink; }).join(","); }
    // Same rows as on screen: skip the swap, it would rebuild every card
    function _setPosts(list) {
        if (!root.loading && root._sig(list) === root._sig(root.posts)) return;
        root.posts = list;
        root.loading = false;
    }
    function _setNotes(list) {
        if (!root.notesLoading && root._sig(list) === root._sig(root.notes)) return;
        root.notes = list;
        root.notesLoading = false;
    }

    // Posts and notes in parallel
    function load() {
        var cachedPosts = FeedCache.peek(root._cacheKey("posts"));
        var cachedNotes = FeedCache.peek(root._cacheKey("notes"));
        if (cachedPosts) root._setPosts(cachedPosts.filter(root._allowed));
        if (cachedNotes) root._setNotes(root._pickNotes(cachedNotes));
        if (cachedPosts || cachedNotes)
            NavPerf.log("suggested cache painted +" + NavPerf.since("feedOpen") + "ms (posts "
                        + (cachedPosts ? cachedPosts.length : 0) + ", notes " + (cachedNotes ? cachedNotes.length : 0) + ")");
        // Callbacks can land after My Feed closed and destroyed us
        root._scoped(PostService.listTrending, 20, function (rows) {
            if (!root) return;
            var picked = root._pickPosts(rows);
            FeedCache.put(root._cacheKey("posts"), picked);
            root._setPosts(picked);
            NavPerf.log("suggested posts +" + NavPerf.since("feedOpen") + "ms (" + picked.length + ")");
        }, function () { if (root) root.loading = false; });
        root._loadNotes();
    }

    // Home notes first, topped up globally (one country rarely fills it)
    function _loadNotes() {
        var want = 9, limit = 12;   // spare rows for hidden/blocked
        function finish(list) {
            FeedCache.put(root._cacheKey("notes"), list);
            root._setNotes(list);
            NavPerf.log("suggested notes +" + NavPerf.since("feedOpen") + "ms (" + list.length + ")");
        }
        function global(first) {
            var params = { limit: limit, offset: 0 };
            if (Config.communityId > 0) params.community_id = Config.communityId;
            else params.exclude_home = 1;
            PostService.listTrendingNotes(Config.baseUrl, params, Session.token, function (rows) {
                if (!root) return;
                var seen = {}, out = [];
                var all = first.concat(root._pickNotes(rows));
                for (var i = 0; i < all.length; i++)
                    if (!seen[all[i].permlink]) { seen[all[i].permlink] = true; out.push(all[i]); }
                finish(out);
            }, function () { if (root) root._setNotes(first.length ? first : root.notes); });
        }
        var home = Config.homeCountryCommunityId;
        if (!home) { global([]); return; }
        PostService.listTrendingNotes(Config.baseUrl, { limit: limit, offset: 0, community_id: home }, Session.token,
            function (rows) {
                if (!root) return;
                var picked = root._pickNotes(rows);
                if (picked.length >= want) finish(picked);
                else global(picked);
            }, function () { if (root) global([]); });
    }

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

    Component.onCompleted: load()

    Connections {
        target: PostActions
        function _drop(permlink) {
            var out = [];
            for (var i = 0; i < root.posts.length; i++)
                if (root.posts[i].permlink !== permlink) out.push(root.posts[i]);
            root.posts = out;
            root.notes = root.notes.filter(function (p) { return p.permlink !== permlink; });
        }
        function onHideRequested(author, permlink) { _drop(permlink); }
        function onPostDeleted(author, permlink) { _drop(permlink); }
        function onUserBlocked(username) {
            root.posts = root.posts.filter(function (p) { return p.author !== username; });
            root.notes = root.notes.filter(function (p) { return p.author !== username; });
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
                text: Lang.tr("Suggested posts")
                font.pixelSize: Style.fontLarge
                font.weight: Font.DemiBold
                font.family: Style.fontFor(text)
                color: Style.textTitle
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

                ListView {
                    id: pager
                    width: parent.width
                    height: carousel.cardH
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: width
                    highlightMoveDuration: 300
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    model: root.loading ? 1 : root.pageCount

                    delegate: Row {
                        id: pageRow
                        readonly property int pageIndex: index
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
                        readonly property bool canGo: modelData < 0 ? pager.currentIndex > 0
                                                                     : pager.currentIndex < root.pageCount - 1
                        visible: !root.loading && root.pageCount > 1
                        enabled: canGo
                        opacity: canGo ? 1 : 0.35
                        width: units.gu(4); height: width
                        x: modelData < 0 ? -width - units.gu(0.5) : carousel.width + units.gu(0.5)
                        y: Math.round(carousel.cardW * 0.62 / 2 - height / 2)
                        onClicked: pager.currentIndex += modelData
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
                        readonly property bool on: index === pager.currentIndex
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
                visible: root.notesLoading || root.notes.length > 0
                x: noteCarousel.x
                text: Lang.tr("Suggested notes")
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
                visible: root.notesLoading || root.notes.length > 0
                readonly property real cardW: (width - root.gap * (root.notesPerPage - 1)) / root.notesPerPage
                readonly property real pad: units.gu(1.25)
                // Header + 4 text lines + image
                readonly property real cardH: Math.round(pad * 2 + units.gu(3.5) + Style.spacingS * 2
                                                         + noteLine.height * 4 + (cardW - pad * 2) * 0.6)
                FontMetrics { id: noteLine; font.pixelSize: Style.fontRegular }

                ListView {
                    id: notePager
                    // Room for ribbon fold
                    width: parent.width + units.gu(1)
                    height: noteCarousel.cardH
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: width
                    highlightMoveDuration: 300
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    model: root.notesLoading ? 1 : root.notePages

                    delegate: Row {
                        id: notePage
                        readonly property int pageIndex: index
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
                        readonly property bool canGo: modelData < 0 ? notePager.currentIndex > 0
                                                                     : notePager.currentIndex < root.notePages - 1
                        visible: !root.notesLoading && root.notePages > 1
                        enabled: canGo
                        opacity: canGo ? 1 : 0.35
                        width: units.gu(4); height: width
                        x: modelData < 0 ? -width - units.gu(0.5) : noteCarousel.width + units.gu(0.5)
                        y: Math.round(noteCarousel.height / 2 - height / 2)
                        onClicked: notePager.currentIndex += modelData
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
                        readonly property bool on: index === notePager.currentIndex
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
