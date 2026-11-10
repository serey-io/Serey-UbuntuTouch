import QtQuick 2.7
import QtMultimedia 5.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PodcastService.js" as PodcastService
import "../services/Mappers.js" as M
import "../services/VoteService.js" as VoteService

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
    // Same split as the Video tab: Chromium <video> for mp4/webm and downloads, media-hub only for remote .mov,
    // which Chromium can't decode. media-hub drops early seeks, ignores speed and can't read our downloads.
    readonly property string _videoUrl: page.isVideo ? (Downloads.pathFor(page.dlKey) || page.episode.contentUrl || "") : ""
    readonly property bool nativeVideo: page.isVideo && page._videoUrl.indexOf("file://") !== 0 && /\.mov(\?|$)/i.test(page._videoUrl)
    readonly property bool webVideo: page.isVideo && !page.nativeVideo
    // YouTube and web video share the VideoWebView path
    readonly property bool webStage: page.isYoutube || page.webVideo
    property bool ytStarted: false
    // set on tap
    property string videoSrc: ""
    // .mov player built early so the tap doesn't freeze
    property bool videoWarm: false
    // this page's own video position, for resume points
    property real _vidPos: 0
    property bool _vidPlaying: false
    property real _videoStartAt: 0

    // controls drive Player (audio), the web view (YouTube, video), or the native .mov player
    readonly property var yt: ytLoader.item
    readonly property var vid: videoLoader.item ? videoLoader.item.media : null
    // page-owned playback (not the global Player)
    readonly property bool ownPlayer: page.webStage || page.nativeVideo
    readonly property bool ctlActive: page.webStage ? !!page.yt : page.nativeVideo ? !!page.vid : page.isCurrent
    readonly property real ctlPos: page.webStage ? (page.yt ? page.yt.position : 0)
                                 : page.nativeVideo ? (page.vid ? Math.max(0, page.vid.position) : 0) : Player.position
    readonly property real ctlDur: page.webStage ? (page.yt ? page.yt.duration : 0)
                                 : page.nativeVideo ? (page.vid ? Math.max(0, page.vid.duration) : 0) : Player.duration
    readonly property bool ctlPlaying: page.webStage ? (!!page.yt && !page.yt.paused)
                                     : page.nativeVideo ? (!!page.vid && page.vid.playbackState === MediaPlayer.PlayingState)
                                     : (page.isCurrent && Player.playing)
    readonly property bool ctlBusy: page.webStage ? (page.ytStarted && (!page.yt || !page.yt.ready))
                                  // same rule as the spinner on the video: media-hub pre-roll reads as paused
                                  : page.nativeVideo ? (page.videoSrc.length > 0 && (!page.vid || (!videoLoader.item._userPaused
                                                    && page.vid.playbackState !== MediaPlayer.PlayingState
                                                    && page.vid.status !== MediaPlayer.EndOfMedia
                                                    && page.vid.status !== MediaPlayer.InvalidMedia)))
                                  : (page.isCurrent && Player.buffering)
    readonly property bool ctlHasNext: page._queueStep(1) >= 0
    // a just-requested seek shows at once instead of snapping back while the player catches up
    property real _seekTarget: -1
    // a pending resume point counts as the position while the video loads
    readonly property real uiPos: page._seekTarget >= 0 ? page._seekTarget
                                  : (page.isVideo && page._videoStartAt > 0) ? page._videoStartAt : page.ctlPos
    onCtlPosChanged: if (page._landed(page.ctlPos)) { page._seekTarget = -1; seekRetry.stop(); }
    // media-hub drops a seek sent too soon after play starts: resend until the position lands, then give up
    property int _seekTries: 0
    function _landed(pos) { return page._seekTarget >= 0 && pos >= page._seekTarget - 1500 && pos <= page._seekTarget + 6000; }
    function _sendSeek() {
        if (page.webStage) { if (page.yt) page.yt.seekTo(page._seekTarget); }
        else if (page.vid) page.vid.seek(page._seekTarget);
    }
    Timer {
        id: seekRetry
        interval: 1500
        repeat: true
        onTriggered: {
            if (page._seekTarget < 0 || page._landed(page.ctlPos)) { page._seekTarget = -1; stop(); return; }
            // Chromium finishes a seek itself, and resending restarts its fetch of that spot: just hold the shown time
            if (page.webStage) { if (++page._seekTries > 30) { page._seekTarget = -1; stop(); } return; }
            if (++page._seekTries > 5) { page._seekTarget = -1; stop(); return; }
            page._sendSeek();
        }
    }

    // skips what can't play here (locked, outside links), like Player's own queue
    function _playableHere(ep) {
        if (!ep || ep.isLocked) return false;
        if (ep.contentType === "link") return /(youtube\.com\/(watch|embed|shorts)|youtu\.be\/)/i.test(ep.contentUrl || "");
        if (ep.contentType === "video") return !!(ep.contentUrl || Downloads.pathFor(Player.key(ep)));
        return Player.canPlay(ep);
    }
    function _queueStep(dir) {
        var i = -1;
        for (var k = 0; k < page.queue.length; k++) if (String(page.queue[k].id) === String(page.episode.id)) { i = k; break; }
        if (i < 0) return -1;
        for (var j = i + dir; j >= 0 && j < page.queue.length; j += dir) if (page._playableHere(page.queue[j])) return j;
        return -1;
    }
    // streamed episodes can't start offline; downloads still can
    function _offlineBlocked() {
        if (Net.online || page.dlSaved) return false;
        Toast.error(Lang.tr("No network right now. Downloaded episodes still play offline."));
        Net.probe();
        return true;
    }
    function _playAudio() { if (!page._offlineBlocked()) Player.play(page.episode, page.queue); }
    function _mode() { return page.isYoutube ? "youtube" : page.webVideo ? "webvideo" : page.nativeVideo ? "native" : page.isAudio ? "audio" : "link"; }
    function startYt() {
        if (page._offlineBlocked()) return;
        Player.log("page " + page.episode.id + " start " + page._mode() + " resume=" + Player.resumePoint(page.episode));
        Player.pause();
        // kept until the video is ready, however long the load takes (no give-up here, unlike media-hub)
        if (page.webVideo && page._videoStartAt <= 0) page._videoStartAt = Player.resumePoint(page.episode);
        page.ytStarted = true;
    }
    function startVideo() {
        if (page._offlineBlocked()) return;
        Player.log("page " + page.episode.id + " start native");
        Player.pause();
        if (page._videoStartAt <= 0) page._videoStartAt = Player.resumePoint(page.episode);
        if (page._videoStartAt > 0) videoStartGiveUp.restart();
        page.videoSrc = page._videoUrl;
    }
    // a fresh pipeline: a reused one hits GStreamer stream errors after switching episodes
    function _reloadVideo() {
        page._videoStartAt = page._vidPos > 0 ? page._vidPos : 0;
        page.videoWarm = false;
        page.videoSrc = "";
        page.startVideo();
    }
    property real _vidDur: 0
    function _saveVideo() { if (page.isVideo) Player.savePoint(page.episode, page._vidPos, page._vidDur); }
    onVideoSrcChanged: if (videoLoader.status === Loader.Ready) page._feedVideo()
    // hand the source to a ready player
    function _feedVideo() {
        var it = videoLoader.item;
        if (!it || it.source === page.videoSrc) return;
        it.media.playbackRate = Player.rate;
        it.media.notifyInterval = 500;
        it.source = page.videoSrc;
    }
    function ctlToggle() {
        if (page.webStage) {
            if (!page.ytStarted) page.startYt();
            else if (page.yt) { if (page.yt.paused) page.yt.play(); else page.yt.pause(); }
        } else if (page.nativeVideo) {
            if (!page.videoSrc) page.startVideo();
            else if (page.vid && (page.vid.error !== MediaPlayer.NoError || page.vid.status === MediaPlayer.InvalidMedia)) page._reloadVideo();
            else if (videoLoader.item) videoLoader.item.togglePause();
        } else if (page.isCurrent) Player.toggle();
        else page._playAudio();
    }
    function ctlSeekTo(ms) {
        var t = Math.max(0, page.ctlDur > 0 ? Math.min(ms, page.ctlDur) : ms);
        if (!page.ownPlayer) { Player.seekTo(t); return; }
        // a seek made while loading replaces the pending resume point
        page._videoStartAt = 0;
        page._seekTarget = t;
        page._seekTries = 0;
        seekRetry.restart();
        // each web seek into a big file restarts its download; a burst of taps or drags sends only the last
        if (page.webStage) webSeekSettle.restart();
        else page._sendSeek();
    }
    property real _lastWebSeek: 0
    Timer {
        id: webSeekSettle
        interval: 400
        onTriggered: {
            if (page._seekTarget < 0) return;
            page._lastWebSeek = Date.now();
            page._loadTicks = 0;
            page._stallTicks = 0;
            page._sendSeek();
        }
    }
    // from the shown position, so quick repeated taps add up
    function ctlSeekBy(d) { page.ctlSeekTo(page.uiPos + d); }
    // the page's queue decides, so audio can step into a video or YouTube episode and back
    function ctlNext() {
        var i = page._queueStep(1);
        if (i >= 0) page.showEpisode(page.queue[i]);
    }
    function ctlPrev() {
        var i = page._queueStep(-1);
        if (page.uiPos > 5000 || i < 0) page.ctlSeekTo(0);
        else page.showEpisode(page.queue[i]);
    }
    // swap episode in place, keep playing
    function showEpisode(ep) {
        Player.log("page switch " + (page.episode ? page.episode.id : "-") + " -> " + ep.id + " (" + ep.contentType + ")");
        page._saveVideo();
        page._vidPos = 0;
        page._vidDur = 0;
        page._seekTarget = -1;
        page._videoStartAt = 0;
        page._webRetries = 0;
        page._stallTicks = 0;
        page._loadTicks = 0;
        page.ytStarted = false;
        page.videoWarm = false;
        page.videoSrc = "";
        page.episode = ep;
        if (page.webStage) page.startYt();
        else if (page.nativeVideo) page.startVideo();
        else if (Player.canPlay(ep)) page._playAudio();
        else Player.pause();
    }
    Connections {
        target: page.vid
        ignoreUnknownSignals: true
        function onStatusChanged() { if (page.vid.status === MediaPlayer.EndOfMedia && Player.autoplayNext) page.ctlNext(); }
        function onPositionChanged() { if (page.vid.position > 0) page._vidPos = page.vid.position; }
        function onDurationChanged() { if (page.vid.duration > 0) page._vidDur = page.vid.duration; page._applyVideoStart(); }
        function onPlaybackStateChanged() {
            page._vidPlaying = page.vid.playbackState === MediaPlayer.PlayingState;
            if (page._vidPlaying) page._applyVideoStart(); else page._saveVideo();
        }
        function onSeekableChanged() { page._applyVideoStart(); }
    }
    Connections {
        target: page.webVideo ? page.yt : null
        ignoreUnknownSignals: true
        function onReadyChanged() { Player.log("page " + page.episode.id + " web ready=" + page.yt.ready); if (page.yt.ready && page._videoStartAt > 0) { var t = page._videoStartAt; page._videoStartAt = 0; page.ctlSeekTo(t); } }
        function onPositionChanged() { if (page.yt.position > 0) page._vidPos = page.yt.position; }
        function onDurationChanged() { if (page.yt.duration > 0) page._vidDur = page.yt.duration; }
        function onPausedChanged() { page._vidPlaying = !page.yt.paused; if (page.yt.paused) page._saveVideo(); }
    }
    // Storage sometimes fails a mid-file fetch (seen on the phone: err=2 after a resume); retry with a fresh request
    property int _webRetries: 0
    property int _stallTicks: 0
    property int _loadTicks: 0
    property int _goodTicks: 0
    function _recoverWeb(why) {
        if (!page.yt) return;
        if (page._webRetries >= 3) {
            Player.log("page " + page.episode.id + " web gave up (" + why + ")");
            Toast.error(Lang.tr("Couldn't play this episode."));
            return;
        }
        page._webRetries++;
        var t = page.uiPos > 0 ? page.uiPos : page._vidPos;
        Player.log("page " + page.episode.id + " web retry " + page._webRetries + " (" + why + ") at " + Math.round(t));
        page.yt.reloadAt(t);
        // a reload restarts at 0 until the seek lands; keep showing where it's going
        page._seekTarget = t;
        page._seekTries = 0;
        seekRetry.restart();
    }
    Connections {
        target: page.webVideo ? page.yt : null
        ignoreUnknownSignals: true
        function onMediaErrorChanged() { if (page.yt.mediaError > 0) page._recoverWeb("error " + page.yt.mediaError); }
    }
    // Reload a fetch that has stopped without data (~6s), or one still loading too long (~8s after a seek, ~10s otherwise).
    Timer {
        interval: 2000
        repeat: true
        running: page.webVideo && page.ytStarted && !!page.yt && !(page.yt.ready && page.yt.paused)
        onTriggered: {
            if (!page.yt.ready || page.yt.readyState < 3) {
                page._goodTicks = 0;
                if (page.yt.networkState === 2) {
                    page._stallTicks = 0;
                    // good loads and seeks reach data in 1-3s on the phone; past ~10s the request is stuck
                    var limit = Date.now() - page._lastWebSeek < 60000 ? 4 : 5;
                    if (++page._loadTicks >= limit) { page._loadTicks = 0; page._recoverWeb("slow"); }
                } else if (++page._stallTicks >= 3) { page._stallTicks = 0; page._recoverWeb("stall"); }
            } else {
                page._stallTicks = 0;
                page._loadTicks = 0;
                if (++page._goodTicks >= 5) page._webRetries = 0;
            }
        }
    }
    // media-hub never emits seekableChanged, so also try once playing with a known length
    function _applyVideoStart() {
        var v = page.vid;
        if (!v || page._videoStartAt <= 0) return;
        if (!v.seekable && !(v.playbackState === MediaPlayer.PlayingState && v.duration > 0)) return;
        var t = page._videoStartAt;
        page._videoStartAt = 0;
        page.ctlSeekTo(t);
    }
    // never leave the shown time parked on a resume point that couldn't be applied
    Timer { id: videoStartGiveUp; interval: 12000; onTriggered: page._videoStartAt = 0 }
    Connections {
        target: Player
        // audio resumed from the mini bar: stop this page's video so both don't play
        function onPlayingChanged() {
            if (!Player.playing || !page.ownPlayer || !page.ctlPlaying) return;
            if (page.webStage) page.yt.pause();
            else if (videoLoader.item) videoLoader.item.togglePause();
        }
        function onRateChanged() {
            if (page.yt) page.yt.setRate(Player.rate);
            if (page.vid && page.nativeVideo) {
                page.vid.playbackRate = Player.rate;
                if (page._vidPlaying) Player.checkRate(page.vid.playbackRate);
            }
        }
    }
    readonly property bool canDownload: !page.locked && (page.isAudio || page.isVideo)
                                        && (page.dlSaved || (page.episode.contentUrl || "").length > 0)
    readonly property bool isCurrent: (Player.current, Player.isCurrent(page.episode))
    readonly property bool canVote: !page.offlineMode && !!page.episode && !!page.episode.author && !!page.episode.permlink
    // manager of the episode's own community, from any platform; locked 7 days after chain, like web
    readonly property bool canManage: !!page.episode && !page.offlineMode
                                      && !!Config.ownedCommunityIdSet[page.episode.communityId || Config.communityId]
                                      && !Config.isPayoutClosed(page.episode.onChainAt)
    property bool busy: false

    // follow autoplay to next episode
    Connections {
        target: Player
        function onCurrentChanged() {
            if (page.visible && Player.current && page.isAudio && !page.isCurrent
                    && page.queue.some(function (e) { return Player.isCurrent(e); }))
                page.episode = Player.current;
        }
    }

    // next/prev can swap audio and video in place
    onIsAudioChanged: Player.setPageShown(page, page.visible && page.isAudio)
    Timer {
        interval: 5000
        repeat: true
        running: page._vidPlaying
        onTriggered: page._saveVideo()
    }
    // Video can't carry on as background audio: on the phone that hangs media-hub. Pause and remember the spot instead.
    onVisibleChanged: {
        Player.log("page " + (page.episode ? page.episode.id : "-") + " visible=" + visible);
        Player.setPageShown(page, visible && page.isAudio);
        if (!visible && page.webStage && page.yt && !page.yt.paused) page.yt.pause();
        if (!visible && page.nativeVideo && page._vidPlaying && videoLoader.item) videoLoader.item.togglePause();
    }
    Timer {
        id: warmVideo
        interval: 500
        onTriggered: if (page.nativeVideo && !page.locked) page.videoWarm = true
    }
    Component.onCompleted: {
        Player.log("page open " + (page.episode ? page.episode.id : "-") + " " + page._mode() + (page.offlineMode ? " offline" : ""));
        warmVideo.start();
        page._syncVotes();
        Player.setPageShown(page, page.isAudio);
        if (!page.locked && !page.isCurrent && (page.ownPlayer || Player.canPlay(page.episode))) autoplay.start();
    }
    // start after the page is on screen; first audio init blocks ~300ms
    Timer {
        id: autoplay
        interval: 350
        onTriggered: {
            if (!page.visible || page.isCurrent) return;
            if (page.webStage) { if (!page.ytStarted) page.startYt(); }
            else if (page.nativeVideo) { if (!page.videoSrc) page.startVideo(); }
            else page._playAudio();
        }
    }
    Connections {
        target: Qt.application
        function onStateChanged() {
            Player.log("app state " + Qt.application.state + " page " + (page.episode ? page.episode.id : "-"));
            if (Qt.application.state !== Qt.ApplicationActive) page._saveVideo();
        }
    }
    Component.onDestruction: {
        Player.log("page close " + (page.episode ? page.episode.id : "-") + " pos=" + page._vidPos);
        page._saveVideo();
        Player.setPageShown(page, false);
    }

    // VoteBar overwrites these, so bindings would stick to the old episode
    onEpisodeChanged: page._syncVotes()
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
        if (page.dlActive) return;
        var ep = Object.assign({}, page.episode, { kind: "podcast", permlink: page.dlKey });
        Downloads.start(ep, page.episode.contentUrl);
    }
    // podcasts tab of the library
    function openDownloads() {
        if (page.offlineMode) page.pageStack.pop();
        else page.pageStack.push(Qt.resolvedUrl("DownloadedContentPage.qml"), { tabIndex: 2 });
    }

    function edit() {
        Player.stop();
        if (page.ctlPlaying && page.ownPlayer) page.ctlToggle();
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
                visible: page.canDownload && !page.dlActive
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
                    visible: page.videoSrc.length === 0 && !page.ytStarted
                    episode: page.episode
                    // list-size first (cached), then sharp
                    property bool sharp: false
                    onSourceChanged: sharp = false
                    onSourceAspectChanged: if (sourceAspect > 0 && !sharp) Qt.callLater(function () { stageCover.sharp = true; })
                    decodeWidth: sharp ? units.gu(64) : units.gu(18)
                }
                Loader {
                    id: videoLoader
                    anchors.fill: parent
                    asynchronous: true
                    active: page.videoWarm || page.videoSrc.length > 0
                    visible: page.videoSrc.length > 0
                    sourceComponent: VideoNativePlayer {
                        onFailed: if (page.visible && page.videoSrc) Toast.error(Lang.tr("Couldn't play this episode."))
                    }
                    // start after creation finishes; gstreamer needs a free main thread for the surface
                    onLoaded: Qt.callLater(page._feedVideo)
                }
                // YouTube or <video>, web view only after tap
                Loader {
                    id: ytLoader
                    anchors.fill: parent
                    active: page.ytStarted
                    sourceComponent: VideoWebView {
                        controls: false
                        reportState: true
                        keepPlaying: true
                        noCache: true
                        onReadyChanged: if (ready) setRate(Player.rate)
                        onEndedChanged: { if (ended) Player.log("page " + page.episode.id + " web ended"); if (ended && Player.autoplayNext) page.ctlNext(); }
                    }
                    // set once, like the Video tab, so a download finishing mid-play doesn't reload it
                    onLoaded: {
                        item.wrap = page.isYoutube;
                        item.directVideo = page.webVideo;
                        item.embedUrl = page.webVideo ? page._videoUrl : page.episode.contentUrl;
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
                                                 ? (drag.pressed ? drag.frac : Math.min(1, page.uiPos / page.ctlDur)) : 0
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
                    readonly property int shownPos: page.ctlActive ? (drag.pressed ? drag.frac * page.ctlDur : page.uiPos) : 0
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
                    // speed is dropped where the native player ignores it; the web view still honours it
                    readonly property bool showSpeed: page.webStage || Player.rateSupported
                    readonly property var cells: (strip.showSpeed
                        ? [{ key: "speed", caption: Lang.tr("Speed"), value: Player.rate + "×", on: Player.rate !== 1 }] : [])
                        .concat([{ key: "autoplay", caption: Lang.tr("Autoplay"), value: Player.autoplayNext ? Lang.tr("On") : Lang.tr("Off"), on: Player.autoplayNext }])

                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: units.dp(1); color: Style.divider }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: units.dp(1); color: Style.divider }
                    Rectangle { visible: strip.cells.length > 1; anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom; margins: Style.spacingS } width: units.dp(1); color: Style.divider }

                    Repeater {
                        model: strip.cells
                        delegate: AbstractButton {
                            id: cell
                            x: index * strip.width / strip.cells.length
                            width: strip.width / strip.cells.length
                            height: strip.height
                            onClicked: {
                                if (modelData.key === "speed") Player.cycleRate();
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
                text: page.episode ? page.episode.description : ""
                visible: text.length > 0
                font.pixelSize: Style.fontRegular
                font.family: Style.fontFor(text)
                color: Style.textPrimary
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
    }

    // votes, serey value
    Rectangle {
        id: voteFooter
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.gu(6)
        visible: page.canVote
        color: Style.surface

        Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

        Item {
            width: Math.min(parent.width, page.maxContentWidth) - Style.spacingM * 2
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

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
}
