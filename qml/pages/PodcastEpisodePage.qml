import QtQuick 2.7
import QtQuick.Window 2.2
import QtMultimedia 5.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PodcastService.js" as PodcastService
import "../services/Mappers.js" as M
import "../services/VoteService.js" as VoteService
import "../services/YouTube.js" as YouTube
import "../services/CommentService.js" as CommentService
import "../services/Notes.js" as Notes

Page {
    id: page

    property var episode: null
    property var queue: []
    // opened from Downloads
    property bool offlineMode: false

    signal changed()

    readonly property real maxContentWidth: units.gu(60)
    readonly property string dlKey: Player.key(page.episode)
    readonly property var dlActive: (Downloads.rev, Downloads.activeFor(page.dlKey))
    readonly property bool dlSaved: (Downloads.rev, Downloads.isSaved(page.dlKey))
    readonly property bool isAudio: !!page.episode && page.episode.contentType === "audio"
    readonly property bool isVideo: !!page.episode && page.episode.contentType === "video"
    readonly property bool locked: !!page.episode && page.episode.isLocked
    readonly property bool isYoutube: !!page.episode && page.episode.contentType === "link"
                                      && /(youtube\.com\/(watch|embed|shorts)|youtu\.be\/)/i.test(page.episode.contentUrl || "")
    readonly property bool wideStage: page.isVideo || page.isYoutube
    // youtube + video play in shared views (Main.qml) shown in this stage, so leaving never restarts them
    readonly property bool onStage: page.wideStage && page.isCurrent

    // all controls drive Player
    readonly property bool ctlActive: page.isCurrent
    readonly property real ctlPos: page.isCurrent ? Player.position : 0
    readonly property real ctlDur: page.isCurrent ? Player.duration : 0
    readonly property bool ctlPlaying: page.isCurrent && Player.playing
    readonly property bool ctlBusy: page.isCurrent && Player.buffering
    readonly property bool ctlHasNext: page.isCurrent && Player.hasNext()

    function ctlToggle() {
        if (page.isCurrent) Player.toggle();
        else Player.play(page.episode, page.queue);
    }
    function ctlSeekTo(ms) { Player.seekTo(ms); }
    function ctlSeekBy(d) { Player.seekBy(d); }
    function ctlNext() { Player.next(); }
    function ctlPrev() { Player.prev(); }

    readonly property bool canDownload: !page.locked && (page.isAudio || page.isVideo || page.isYoutube)
                                        && (page.dlSaved || (page.episode.contentUrl || "").length > 0)
    readonly property bool canVote: !page.offlineMode && !!page.episode && !!page.episode.author && !!page.episode.permlink
    // youtube link -> direct file in flight
    property bool ytExtracting: false
    readonly property bool isCurrent: (Player.current, Player.isCurrent(page.episode))
    // manager of the episode's own community, from any platform; locked 7 days after chain, like web
    readonly property bool canManage: !!page.episode && !page.offlineMode
                                      && !!Config.ownedCommunityIdSet[page.episode.communityId || Config.communityId]
                                      && !Config.isPayoutClosed(page.episode.onChainAt)
    property bool busy: false

    // comments
    readonly property bool canComment: !page.offlineMode && !!page.episode && !!page.episode.id
    property var comments: []
    property int commentCount: 0
    property bool posting: false
    property var replyTarget: null
    property var editTarget: null
    readonly property real kbHeight: Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0

    function loadComments() {
        if (!page.canComment) { page.comments = []; page.commentCount = 0; return; }
        var id = page.episode.id;
        PodcastService.comments(Config.baseUrl, id, Session.token,
            function (rows) {
                if (!page.episode || page.episode.id !== id) return;
                page.comments = rows;
                page.commentCount = page._countAll(rows);
            },
            function () {});
    }
    function _countAll(list) {
        var n = 0;
        for (var i = 0; i < list.length; i++) n += 1 + page._countAll(list[i].replies || []);
        return n;
    }
    function _appendReply(list, parentPermlink, reply) {
        return list.map(function (node) {
            if (node.permlink === parentPermlink)
                return Object.assign({}, node, { replies: [reply].concat(node.replies || []) });
            if (node.replies && node.replies.length)
                return Object.assign({}, node, { replies: page._appendReply(node.replies, parentPermlink, reply) });
            return node;
        });
    }
    function _removeFrom(list, permlink) {
        return list.filter(function (node) { return node.permlink !== permlink; }).map(function (node) {
            return node.replies && node.replies.length
                ? Object.assign({}, node, { replies: page._removeFrom(node.replies, permlink) }) : node;
        });
    }
    function _editIn(list, permlink, body) {
        return list.map(function (node) {
            if (node.permlink === permlink) return Object.assign({}, node, { body: body });
            if (node.replies && node.replies.length)
                return Object.assign({}, node, { replies: page._editIn(node.replies, permlink, body) });
            return node;
        });
    }
    // page scope: CommentService is null inside Loader reply rows
    function removeComment(permlink) {
        page.comments = page._removeFrom(page.comments, permlink);
        page.commentCount = page._countAll(page.comments);
        Toast.success(Lang.tr("Comment deleted"));
        CommentService.remove(Config.baseUrl, permlink, Session.username, Session.token,
            function () {},
            function (err) {
                Toast.error((err && err.message) ? err.message : Lang.tr("Couldn't delete comment."));
                page.loadComments();
            });
    }
    function startReply(c) {
        if (!Session.isLoggedIn) { page.pageStack.push(Qt.resolvedUrl("LoginPage.qml")); return; }
        page.editTarget = null; page.replyTarget = c;
        composer.forceActiveFocus(); Qt.inputMethod.show();
    }
    function startEdit(c) {
        page.replyTarget = null; page.editTarget = c;
        composer.text = c.body || "";
        composer.forceActiveFocus(); Qt.inputMethod.show();
    }
    function cancelCompose() { page.replyTarget = null; page.editTarget = null; composer.text = ""; }
    function submitComment() {
        if (page.posting || !page.canComment) return;
        var text = Style.sentenceCase(composer.text.trim());
        if (text.length === 0) return;
        if (!Session.isLoggedIn) { page.pageStack.push(Qt.resolvedUrl("LoginPage.qml")); return; }
        var edited = page.editTarget, target = page.replyTarget;
        var body = { body: text };
        if (edited) body.permlink = edited.permlink;
        else if (target) { body.parent_author = target.author; body.parent_permlink = target.permlink; }
        page.posting = true;
        PodcastService.saveComment(Config.baseUrl, page.episode.id, body, Session.token,
            function () {
                page.posting = false;
                page.cancelCompose();
                if (edited) {
                    page.comments = page._editIn(page.comments, edited.permlink, text);
                    Toast.success(Lang.tr("Comment updated"));
                } else {
                    var mine = { author: Session.username, permlink: "", body: text,
                                 date: Lang.tr("just now"), votes: 0, voters: [], replies: [],
                                 authorImage: Session.avatarUrl };
                    page.comments = target ? page._appendReply(page.comments, target.permlink, mine)
                                           : [mine].concat(page.comments);
                    page.commentCount = page.commentCount + 1;
                    Toast.success(Lang.tr("Comment posted"));
                }
                // real permlinks for the optimistic row
                page.loadComments();
            },
            function (err) {
                page.posting = false;
                Toast.error((err && err.message) ? err.message : Lang.tr("Couldn't post comment."));
            });
    }
    function openProfile(username) {
        if (username) page.pageStack.push(Qt.resolvedUrl("ProfileViewPage.qml"), { username: username });
    }

    // follow autoplay / next / prev
    Connections {
        target: Player
        function onCurrentChanged() {
            if (page.visible && Player.current && !page.isCurrent
                    && page.queue.some(function (e) { return Player.isCurrent(e); }))
                page.episode = Player.current;
        }
    }

    // video full screen
    property bool fullscreen: false
    onFullscreenChanged: page._syncShown()
    onIsCurrentChanged: page._syncShown()
    onOnStageChanged: { if (!page.onStage) page.fullscreen = false; page._syncShown(); }
    function _syncShown() {
        Player.setPageShown(page, page.visible && (page.isAudio || page.onStage));
        Player.setStage(page, page.fullscreen ? fsHost : stage, page.visible && page.onStage);
    }
    onVisibleChanged: { if (!page.visible) page.fullscreen = false; page._syncShown(); }
    // build the shared video player before playing
    Timer {
        id: warmVideo
        interval: 500
        onTriggered: if (Player.isVideo(page.episode) && !page.locked) Player.vidWarm = true
    }
    Component.onCompleted: {
        warmVideo.start();
        page._syncVotes();
        page.loadComments();
        page._syncShown();
        if (!page.locked && !page.isCurrent && Player.canPlay(page.episode)) autoplay.start();
    }
    // start after the page is on screen; first media init blocks ~300ms
    Timer {
        id: autoplay
        interval: 350
        onTriggered: if (page.visible && !page.isCurrent) Player.play(page.episode, page.queue)
    }
    Component.onDestruction: { Player.setPageShown(page, false); Player.setStage(page, null, false); }

    // VoteBar overwrites these, so bindings would stick to the old episode
    onEpisodeChanged: { page._syncVotes(); page.cancelCompose(); page.loadComments(); }
    function _syncVotes() {
        var ep = page.episode;
        if (!ep || !voteBar) return;
        var voters = ep.voters || [], flaggers = ep.flaggers || [];
        voteBar.flaggers = flaggers.length;
        var cached = VoteService.getCached(ep.author, ep.permlink);
        voteBar.upvoted = cached ? cached.upvoted : voters.indexOf(Session.username) >= 0;
        voteBar.flagged = cached ? cached.flagged : flaggers.indexOf(Session.username) >= 0;
        voteBar.votes = cached ? cached.votes : voters.length;
        voteBar.payout = (cached && cached.payout) || ep.payout || "";
    }

    // Config.communityDns is the country's; a platform episode needs its own site
    function share() {
        var c = Config.communityById[String(page.episode.communityId)];
        Share.open(PodcastService.shareUrl(page.episode, (c && c.dns) || Config.communityDns));
    }

    function download() {
        if (page.dlSaved) { page.openDownloads(); return; }
        if (page.dlActive || page.ytExtracting) return;
        var ep = Object.assign({}, page.episode, { kind: "podcast", permlink: page.dlKey });
        if (!page.isYoutube) { Downloads.start(ep, page.episode.contentUrl); return; }
        var m = (page.episode.contentUrl || "").match(/(?:youtube\.com\/(?:embed\/|watch\?v=|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/);
        if (!m) { Toast.error(Lang.tr("This YouTube video can't be downloaded.")); return; }
        page.ytExtracting = true;
        Toast.show(Lang.tr("Preparing download…"));
        YouTube.extract(m[1], function (result, errMsg) {
            page.ytExtracting = false;
            if (result && result.url) Downloads.start(ep, result.url);
            else {
                Toast.error(Lang.tr("This YouTube video can't be downloaded."));
                console.log("YouTube extract failed: " + (errMsg || "unknown"));
            }
        });
    }
    // podcasts tab of the library
    function openDownloads() {
        if (page.offlineMode) page.pageStack.pop();
        else page.pageStack.push(Qt.resolvedUrl("DownloadedContentPage.qml"), { tabIndex: 2 });
    }

    function edit() {
        Player.stop();
        var p = page.pageStack.push(Qt.resolvedUrl("CreatePodcastEpisodePage.qml"), { editEpisode: page.episode });
        if (p && p.saved) p.saved.connect(function (body) {
            var e = M.toEpisode(body);
            page.episode = Object.assign({}, page.episode, {
                title: e.title, description: e.description, thumbnail: e.thumbnail,
                contentType: e.contentType, contentUrl: e.contentUrl, seasonNumber: e.seasonNumber,
                episodeNumber: e.episodeNumber, episodeLabel: e.episodeLabel, duration: e.duration,
                publishCeilingId: e.publishCeilingId !== undefined ? e.publishCeilingId : page.episode.publishCeilingId
            });
            page.changed();
            page.pageStack.pop();
        });
    }

    function doDelete() {
        page.busy = true;
        PodcastService.remove(Config.baseUrl, page.episode.id, Session.token,
            function () {
                page.busy = false;
                if (Player.isCurrent(page.episode)) Player.stop();
                Toast.success(Lang.tr("Episode deleted"));
                page.changed();
                page.pageStack.pop();
            },
            function (err) {
                page.busy = false;
                Toast.error((err && err.message) || Lang.tr("Couldn't delete episode."));
            });
    }

    header: PageHeader {
        title: page.episode ? page.episode.title : ""
        trailingActionBar.actions: [
            Action {
                iconName: "share"
                text: Lang.tr("Share…")
                onTriggered: page.share()
            },
            Action {
                // blue when saved
                iconSource: page.dlSaved ? Qt.resolvedUrl("../../assets/save-to-blue.svg") : "image://theme/save-to"
                text: page.dlSaved ? Lang.tr("Downloaded") : Lang.tr("Download")
                visible: page.canDownload && !page.dlActive && !page.ytExtracting
                onTriggered: page.download()
            },
            Action {
                iconSource: Qt.resolvedUrl("../../assets/more-dots.svg")
                text: Lang.tr("More")
                visible: page.canManage
                onTriggered: manageSheet.show([
                    { iconName: "edit", text: Lang.tr("Edit"),
                      onTriggered: function () { page.edit(); } },
                    { iconName: "delete", text: Lang.tr("Delete episode"), danger: true,
                      onTriggered: function () { PopupUtils.open(deleteDialog); } }
                ])
            }
        ]
    }

    Flickable {
        id: scroll
        anchors { top: page.header.bottom; bottom: voteFooter.visible ? voteFooter.top : parent.bottom; horizontalCenter: parent.horizontalCenter }
        // scrolling closes the keyboard
        onMovementStarted: if (composer.activeFocus) Qt.inputMethod.hide()
        width: Math.min(parent.width, page.maxContentWidth)
        contentHeight: col.height + Style.spacingL * 2
        clip: true

        Column {
            id: col
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            y: Style.spacingL
            spacing: Style.spacingM

            // cover / video
            Rectangle {
                id: stage
                width: page.wideStage ? parent.width : Math.min(parent.width, units.gu(32))
                height: page.wideStage ? width * 9 / 16 : width
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Style.thumbRadius
                color: page.wideStage ? Style.videoStage : Style.iconBackground
                clip: true

                CoverArt {
                    id: stageCover
                    anchors.fill: parent
                    visible: !page.onStage
                    episode: page.episode
                    // list-size first (cached), then sharp
                    property bool sharp: false
                    onSourceChanged: sharp = false
                    onSourceAspectChanged: if (sourceAspect > 0 && !sharp) Qt.callLater(function () { stageCover.sharp = true; })
                    decodeWidth: sharp ? units.gu(64) : units.gu(18)
                }
                // youtube / video view is parented here by Main.qml

                // full screen
                AbstractButton {
                    anchors { right: parent.right; bottom: parent.bottom; margins: units.gu(1) }
                    width: units.gu(4.5); height: width
                    z: 10
                    visible: page.onStage && !page.locked
                    onClicked: page.fullscreen = true
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.5); height: width
                            name: "view-fullscreen"
                            color: "white"
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Style.spacingXs
                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: page.episode ? [page.episode.seasonTitle || (Lang.tr("Season") + " " + page.episode.seasonNumber),
                                          Player.episodeLabel(page.episode), Player.durationLabel(page.episode)]
                                         .filter(function (s) { return s; }).join(" · ") : ""
                    font.pixelSize: Style.fontSmall
                    color: Style.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    width: parent.width
                    text: page.episode ? page.episode.title : ""
                    font.pixelSize: Style.fontTitle
                    font.family: Style.fontFor(text)
                    font.weight: Font.DemiBold
                    color: Style.textTitle
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                PublisherLine {
                    width: parent.width
                    episode: page.episode
                    centered: true
                    avatarSize: units.gu(3)
                }
            }

            // download progress
            Label {
                width: parent.width
                visible: !!page.dlActive
                text: page.dlActive ? Lang.tr("Downloading…") + " " + Math.round(page.dlActive.progress) + "%" : ""
                font.pixelSize: Style.fontSmall
                color: Style.brand
                horizontalAlignment: Text.AlignHCenter
            }

            // locked notice
            Rectangle {
                width: parent.width
                visible: page.locked
                height: lockLabel.implicitHeight + Style.spacingM * 2
                radius: Style.cardRadius
                color: Style.iconBackground
                Label {
                    id: lockLabel
                    anchors { fill: parent; margins: Style.spacingM }
                    text: Lang.tr("This is a premium episode. Subscribe to this platform to listen.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Style.fontSmall
                    color: Style.textSecondary
                }
            }

            // link episode
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!page.episode && page.episode.contentType === "link" && !page.locked && !page.isYoutube
                text: Lang.tr("Open episode link")
                color: Style.brand
                onClicked: Qt.openUrlExternally(page.episode.contentUrl)
            }

            // audio controls
            Column {
                width: parent.width
                visible: (page.isAudio || page.isYoutube || page.isVideo) && !page.locked
                spacing: Style.spacingS

                // seek bar
                Item {
                    id: seekBar
                    width: parent.width
                    height: units.gu(4)
                    readonly property real frac: page.ctlActive && page.ctlDur > 0
                                                 ? (drag.pressed ? drag.frac : Math.min(1, page.ctlPos / page.ctlDur)) : 0
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: units.dp(3)
                        color: Style.divider
                        Rectangle { width: parent.width * seekBar.frac; height: parent.height; color: Style.textPrimary }
                    }
                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * seekBar.frac - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.dp(4)
                        height: drag.pressed ? units.gu(3) : units.gu(2)
                        color: Style.brand
                        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuart } }
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        enabled: page.ctlActive && page.ctlDur > 0
                        // keep the page from scrolling away mid-drag
                        preventStealing: true
                        property real frac: 0
                        function at(x) { return Math.max(0, Math.min(1, x / width)); }
                        onPressed: frac = at(mouse.x)
                        onPositionChanged: frac = at(mouse.x)
                        onReleased: page.ctlSeekTo(frac * page.ctlDur)
                    }
                }

                // times
                Item {
                    id: times
                    width: parent.width
                    height: posLabel.height
                    readonly property int shownPos: page.ctlActive ? (drag.pressed ? drag.frac * page.ctlDur : page.ctlPos) : 0
                    Label {
                        id: posLabel
                        text: Player.fmt(times.shownPos)
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.DemiBold
                        color: Style.textPrimary
                    }
                    Label {
                        anchors.right: parent.right
                        text: page.ctlActive && page.ctlDur > 0
                              ? "−" + Player.fmt(Math.max(0, page.ctlDur - times.shownPos))
                              : Player.durationLabel(page.episode)
                        font.pixelSize: Style.fontSmall
                        color: Style.textSecondary
                    }
                }

                Item { width: 1; height: Style.spacingS }

                // transport
                Row {
                    id: transport
                    width: parent.width
                    readonly property real slot: width / 5
                    Item {
                        width: transport.slot; height: playBtn.height
                        PlayerButton { anchors.centerIn: parent; icon: "media-skip-backward"; enabled: page.ctlActive; onClicked: page.ctlPrev() }
                    }
                    Item {
                        width: transport.slot; height: playBtn.height
                        PlayerButton { anchors.centerIn: parent; icon: "media-seek-backward"; caption: "15"; enabled: page.ctlActive; onClicked: page.ctlSeekBy(-15000) }
                    }
                    Item {
                        width: transport.slot; height: playBtn.height
                        PlayerButton {
                            id: playBtn
                            anchors.centerIn: parent
                            big: true
                            busy: page.ctlBusy
                            icon: page.ctlPlaying ? "media-playback-pause" : "media-playback-start"
                            onClicked: page.ctlToggle()
                        }
                    }
                    Item {
                        width: transport.slot; height: playBtn.height
                        PlayerButton { anchors.centerIn: parent; icon: "media-seek-forward"; caption: "30"; enabled: page.ctlActive; onClicked: page.ctlSeekBy(30000) }
                    }
                    Item {
                        width: transport.slot; height: playBtn.height
                        PlayerButton { anchors.centerIn: parent; icon: "media-skip-forward"; enabled: page.ctlActive && page.ctlHasNext; onClicked: page.ctlNext() }
                    }
                }

                Item { width: 1; height: Style.spacingS }

                // speed + autoplay strip
                Item {
                    id: strip
                    width: parent.width
                    height: units.gu(7)

                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: units.dp(1); color: Style.divider }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: units.dp(1); color: Style.divider }
                    Rectangle { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom; margins: Style.spacingS } width: units.dp(1); color: Style.divider }

                    Repeater {
                        model: [
                            { caption: Lang.tr("Speed"), value: Player.rate + "×", on: Player.rate !== 1 },
                            { caption: Lang.tr("Autoplay"), value: Player.autoplayNext ? Lang.tr("On") : Lang.tr("Off"), on: Player.autoplayNext }
                        ]
                        delegate: AbstractButton {
                            id: cell
                            x: index * strip.width / 2
                            width: strip.width / 2
                            height: strip.height
                            onClicked: {
                                if (index === 0) Player.cycleRate();
                                else Player.autoplayNext = !Player.autoplayNext;
                            }
                            Rectangle { anchors.fill: parent; anchors.margins: units.dp(1); color: cell.pressed ? Style.pressed : "transparent" }
                            Column {
                                anchors.centerIn: parent
                                spacing: units.dp(2)
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.caption
                                    font.pixelSize: Style.fontXSmall
                                    color: Style.textSecondary
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.value
                                    font.pixelSize: Style.fontMedium
                                    font.weight: Font.DemiBold
                                    color: modelData.on ? Style.brand : Style.textPrimary
                                }
                            }
                            KeyTapArea { onActivated: cell.clicked() }
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: page.isCurrent && Player.error.length > 0
                    text: Player.error
                    font.pixelSize: Style.fontSmall
                    color: Style.danger
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }


            Label {
                id: descLabel
                width: parent.width
                property string raw: page.episode ? (page.episode.description || "") : ""
                // URLs tappable
                text: Notes.linkifyPlain(raw, Style.brand)
                visible: raw.length > 0
                font.pixelSize: Style.fontRegular
                font.family: Style.fontFor(raw)
                color: Style.textPrimary
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: Qt.openUrlExternally(link)
            }

            // comments
            Column {
                visible: page.canComment
                width: parent.width
                spacing: Style.spacingS

                Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

                Label {
                    width: parent.width
                    text: Lang.tr("COMMENTS (%1)").arg(page.commentCount)
                    font.pixelSize: Style.fontSmall
                    font.weight: Font.Bold
                    color: Style.textSecondary
                }

                Label {
                    width: parent.width
                    visible: page.comments.length === 0
                    text: Lang.tr("No comments yet. Be the first!")
                    textSize: Label.Small
                    color: Style.textSecondary
                }

                Repeater {
                    model: page.comments
                    delegate: CommentItem {
                        width: parent.width
                        comment: modelData
                        onDeleted: page.removeComment(permlink)
                        onEditRequested: page.startEdit(comment)
                        onReplyRequested: page.startReply(comment)
                        onAuthorClicked: page.openProfile(author)
                    }
                }
            }
        }
    }

    // votes, serey value
    Rectangle {
        id: voteFooter
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: page.kbHeight }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        height: footerCol.height
        visible: page.canVote || page.canComment
        color: Style.surface

        Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

        Column {
            id: footerCol
            width: Math.min(parent.width, page.maxContentWidth) - Style.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            bottomPadding: page.canComment ? Style.spacingS : 0

        Item {
            visible: page.canVote
            width: parent.width
            height: visible ? units.gu(6) : 0

            VoteBar {
                id: voteBar
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                author: page.episode ? page.episode.author : ""
                permlink: page.episode ? page.episode.permlink : ""
                voteType: "podcast"
                voters: page.episode ? page.episode.voters || [] : []
                onChain: !!page.episode && !!page.episode.earnsRewards
                createdAt: page.episode ? page.episode.onChainAt || "" : ""
                showComments: false
                showShare: false
                onRequireLogin: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
            }
        }

        // composer
        Column {
            visible: page.canComment
            width: parent.width
            topPadding: page.canVote ? 0 : Style.spacingS
            spacing: units.dp(4)

            Row {
                visible: page.replyTarget !== null || page.editTarget !== null
                width: parent.width
                spacing: Style.spacingS

                Label {
                    text: page.editTarget ? Lang.tr("Editing your comment")
                        : page.replyTarget ? Lang.tr("Replying to @%1").arg(page.replyTarget.author) : ""
                    font.pixelSize: Style.fontSmall
                    color: Style.textSecondary
                }
                AbstractButton {
                    width: cancelLabel.implicitWidth
                    height: cancelLabel.implicitHeight
                    onClicked: page.cancelCompose()
                    Label {
                        id: cancelLabel
                        text: Lang.tr("Cancel")
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.DemiBold
                        color: Style.brand
                    }
                }
            }

            Item {
                width: parent.width
                height: units.gu(5)

                Rectangle {
                    anchors.fill: parent
                    radius: Style.cardRadius
                    color: Style.iconBackground
                    border.width: units.dp(1)
                    border.color: Style.divider
                }

                TextField {
                    id: composer
                    AutoCapitalize { field: composer }
                    anchors { left: parent.left; leftMargin: Style.spacingM; right: sendButton.left; rightMargin: Style.spacingXs; verticalCenter: parent.verticalCenter }
                    height: parent.height - units.dp(2)
                    StyleHints {
                        backgroundColor: "transparent"
                        borderColor: "transparent"
                        color: Style.textPrimary
                    }
                    hasClearButton: false
                    placeholderText: !Session.isLoggedIn ? Lang.tr("Log in to comment…")
                                   : page.editTarget ? Lang.tr("Edit your comment…")
                                                     : Lang.tr("Post a comment…")
                    font.family: Style.fontFor(text)
                    font.pixelSize: Style.fontRegular
                    onAccepted: page.submitComment()
                    onActiveFocusChanged: if (activeFocus) Qt.inputMethod.show()
                }

                AbstractButton {
                    id: sendButton
                    anchors { right: parent.right; rightMargin: units.dp(3); verticalCenter: parent.verticalCenter }
                    width: units.gu(3.8); height: width
                    enabled: !page.posting && composer.displayText.trim().length > 0
                    onClicked: page.submitComment()

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: sendButton.enabled ? Style.brand : "transparent"
                    }
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.2); height: width
                        name: "send"
                        color: sendButton.enabled ? Style.textOnBrand : Style.textSecondary
                    }
                }
            }
        }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        visible: page.busy
        z: 100
        MouseArea { anchors.fill: parent }
        ActivityIndicator { anchors.centerIn: parent; running: page.busy }
    }

    ActionBottomSheet { id: manageSheet }

    Component {
        id: deleteDialog
        Dialog {
            id: ddlg
            title: Lang.tr("Delete “%1”?").arg(page.episode ? page.episode.title : "")
            text: Lang.tr("This episode will be removed from the podcast for everyone.")
            Button {
                text: Lang.tr("Delete")
                color: Style.danger
                onClicked: { PopupUtils.close(ddlg); page.doDelete(); }
            }
            Button { text: Lang.tr("Cancel"); onClicked: PopupUtils.close(ddlg) }
        }
    }

    // full screen host
    Item {
        id: fsHost
        parent: (page.fullscreen && Window.contentItem) ? Window.contentItem : page
        anchors.fill: parent
        z: 2000
        visible: page.fullscreen
        focus: page.fullscreen
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                page.fullscreen = false;
                event.accepted = true;
            }
        }
        Rectangle { anchors.fill: parent; color: "black" }
        // exit
        AbstractButton {
            anchors { right: parent.right; bottom: parent.bottom; margins: units.gu(1.5) }
            width: units.gu(5); height: width
            z: 10
            onClicked: page.fullscreen = false
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.55)
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.5); height: width
                    name: "view-restore"
                    color: "white"
                }
            }
        }
    }
}
