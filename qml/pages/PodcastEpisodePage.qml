import QtQuick 2.7
import QtMultimedia 5.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/PodcastService.js" as PodcastService
import "../services/Mappers.js" as M

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
    property bool ytStarted: false
    // set on tap
    property string videoSrc: ""
    // video player built early so the tap doesn't freeze
    property bool videoWarm: false
    // video <-> background audio handoff
    property real _vidPos: 0
    property bool _vidPlaying: false
    property real _videoStartAt: 0

    // controls drive Player (audio), the youtube view, or the native video
    readonly property var yt: ytLoader.item
    readonly property var vid: videoLoader.item ? videoLoader.item.media : null
    // page-owned playback (not the global Player)
    readonly property bool ownPlayer: page.isYoutube || page.isVideo
    readonly property bool ctlActive: page.isYoutube ? !!page.yt : page.isVideo ? !!page.vid : page.isCurrent
    readonly property real ctlPos: page.isYoutube ? (page.yt ? page.yt.position : 0)
                                 : page.isVideo ? (page._videoStartAt > 0 ? page._videoStartAt : page.vid ? page.vid.position : 0) : Player.position
    readonly property real ctlDur: page.isYoutube ? (page.yt ? page.yt.duration : 0)
                                 : page.isVideo ? (page.vid && page.vid.duration > 0 ? page.vid.duration : page._vidDurHint) : Player.duration
    readonly property bool ctlPlaying: page.isYoutube ? (!!page.yt && !page.yt.paused)
                                     : page.isVideo ? (!!page.vid && page.vid.playbackState === MediaPlayer.PlayingState)
                                     : (page.isCurrent && Player.playing)
    readonly property bool ctlBusy: page.isYoutube ? (page.ytStarted && (!page.yt || !page.yt.ready))
                                  : page.isVideo ? (page.videoSrc.length > 0 && (!page.vid || page.vid.status === MediaPlayer.Loading
                                                                                 || page.vid.status === MediaPlayer.Stalled))
                                  : (page.isCurrent && Player.buffering)
    readonly property bool ctlHasNext: page.ownPlayer ? page._queueStep(1) >= 0 : Player.hasNext()

    function _queueStep(dir) {
        var i = -1;
        for (var k = 0; k < page.queue.length; k++) if (String(page.queue[k].id) === String(page.episode.id)) { i = k; break; }
        if (i < 0) return -1;
        for (var j = i + dir; j >= 0 && j < page.queue.length; j += dir) if (!page.queue[j].isLocked) return j;
        return -1;
    }
    function startYt() { Player.pause(); page.ytStarted = true; }
    function startVideo() {
        Player.pause();
        page.videoSrc = Downloads.pathFor(page.dlKey) || page.episode.contentUrl;
    }
    onVideoSrcChanged: if (videoLoader.status === Loader.Ready) page._feedVideo()
    // hand the source to a ready player
    function _feedVideo() {
        var it = videoLoader.item;
        if (!it || it.source === page.videoSrc) return;
        it.media.playbackRate = Player.rate;
        it.source = page.videoSrc;
    }
    function ctlToggle() {
        if (page.isYoutube) {
            if (!page.ytStarted) page.startYt();
            else if (page.yt) { if (page.yt.paused) page.yt.play(); else page.yt.pause(); }
        } else if (page.isVideo) {
            if (!page.videoSrc) page.startVideo();
            else if (videoLoader.item) videoLoader.item.togglePause();
        } else if (page.isCurrent) Player.toggle();
        else Player.play(page.episode, page.queue);
    }
    function ctlSeekTo(ms) {
        if (page.isYoutube) { if (page.yt) page.yt.seekTo(ms); }
        else if (page.isVideo) { if (page.vid) page.vid.seek(ms); }
        else Player.seekTo(ms);
    }
    function ctlSeekBy(d) { page.ctlSeekTo(Math.max(0, page.ctlPos + d)); }
    function ctlNext() {
        if (!page.ownPlayer) { Player.next(); return; }
        var i = page._queueStep(1);
        if (i >= 0) page.showEpisode(page.queue[i]);
    }
    function ctlPrev() {
        if (!page.ownPlayer) { Player.prev(); return; }
        var i = page._queueStep(-1);
        if (page.ctlPos > 5000 || i < 0) page.ctlSeekTo(0);
        else page.showEpisode(page.queue[i]);
    }
    // swap episode in place, keep playing
    function showEpisode(ep) {
        page.ytStarted = false;
        page.videoSrc = "";
        page.episode = ep;
        if (page.isYoutube) page.startYt();
        else if (page.isVideo) page.startVideo();
        else if (Player.canPlay(ep)) Player.play(ep, page.queue);
        else Player.pause();
    }
    Connections {
        target: page.vid
        ignoreUnknownSignals: true
        function onStatusChanged() { if (page.vid.status === MediaPlayer.EndOfMedia && Player.autoplayNext) page.ctlNext(); }
        function onPositionChanged() {
            var p = page.vid.position;
            if (page._videoStartAt <= 0) { page._vidPos = p; return; }
            if (p >= page._videoStartAt - 3000 || Date.now() - page._vidStartTime > 10000) page._videoStartAt = 0;
            else if (p > 0 && Date.now() - page._vidSeekAt > 1500) page._seekVideoStart();
        }
        function onPlaybackStateChanged() {
            page._vidPlaying = page.vid.playbackState === MediaPlayer.PlayingState;
            if (page._vidPlaying) { if (page._videoStartAt > 0) page._vidMute(true); page._seekVideoStart(); }
        }
        function onSeekableChanged() { page._seekVideoStart(); }
    }
    // media-hub drops early seeks; retried from position updates
    property real _vidSeekAt: 0
    property real _vidStartTime: 0
    property real _vidDurHint: 0
    // silent until the resume seek lands
    function _vidMute(on) { if (!page.vid) return; page.vid.muted = !on; page.vid.muted = on; }
    on_VideoStartAtChanged: if (_videoStartAt <= 0) _vidMute(false)
    function _seekVideoStart() {
        if (page._videoStartAt > 0 && page.vid && page.vid.seekable) { page.vid.seek(page._videoStartAt); page._vidSeekAt = Date.now(); }
    }
    Connections {
        target: Player
        function onRateChanged() {
            if (page.yt) page.yt.setRate(Player.rate);
            if (page.vid) page.vid.playbackRate = Player.rate;
        }
    }
    readonly property bool canDownload: !page.locked && (page.isAudio || page.isVideo)
                                        && (page.dlSaved || (page.episode.contentUrl || "").length > 0)
    readonly property bool isCurrent: (Player.current, Player.isCurrent(page.episode))
    readonly property bool canManage: !!page.episode && Config.isOwnerCurrent && !page.offlineMode
                                      && (!page.episode.communityId || page.episode.communityId === Config.communityId)
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

    onVisibleChanged: {
        Player.setPageShown(page, visible && page.isAudio);
        if (visible) page._takeOver(); else page._handOff();
    }
    // leaving: keep the video going as audio
    function _handOff() {
        if (!page.isVideo || !page._vidPlaying) return;
        page._vidPlaying = false;
        var dur = page.vid ? page.vid.duration : 0;
        if (videoLoader.item) videoLoader.item.source = "";
        Player.play(page.episode, page.queue, page._vidPos, dur);
    }
    // back: resume the video where audio is
    function _takeOver() {
        if (!page.isVideo || !Player.isCurrent(page.episode)) return;
        page._videoStartAt = Math.max(Player.position, Player._resumeTo);
        page._vidPos = page._videoStartAt;
        page._vidStartTime = Date.now();
        page._vidDurHint = Player.duration;
        Player.stop();
        // fresh player: the old one loses its video surface after the handoff
        page.videoSrc = "";
        page.videoWarm = false;
        Qt.callLater(function () { page.videoWarm = true; page.startVideo(); });
    }
    Timer {
        id: warmVideo
        interval: 500
        // also warm the bar player for the back handoff
        onTriggered: if (page.isVideo && !page.locked) { page.videoWarm = true; Player._ensureAudio(); }
    }
    Component.onCompleted: {
        warmVideo.start();
        Player.setPageShown(page, page.isAudio);
        page._takeOver();
        // video loader is async, safe to start now
        if (page.isVideo && !page.locked && !page.videoSrc) page.startVideo();
        else if (!page.locked && !page.isCurrent && (page.ownPlayer || Player.canPlay(page.episode))) autoplay.start();
    }
    // start after the page is on screen; first audio init blocks ~300ms
    Timer {
        id: autoplay
        interval: 350
        onTriggered: {
            if (!page.visible || page.isCurrent) return;
            if (page.isYoutube) { if (!page.ytStarted) page.startYt(); }
            else if (page.isVideo) { if (!page.videoSrc) page.startVideo(); }
            else Player.play(page.episode, page.queue);
        }
    }
    Component.onDestruction: { Player.setPageShown(page, false); page._handOff(); }

    function share() { Share.open(PodcastService.shareUrl(page.episode, Config.communityDns)); }

    function download() {
        if (page.dlSaved) { PopupUtils.open(removeDialog); return; }
        if (page.dlActive) return;
        var ep = Object.assign({}, page.episode, { kind: "podcast", permlink: page.dlKey });
        Downloads.start(ep, page.episode.contentUrl);
    }

    function edit() {
        var p = page.pageStack.push(Qt.resolvedUrl("CreatePodcastEpisodePage.qml"), { editEpisode: page.episode });
        if (p && p.saved) p.saved.connect(function (body) {
            var e = M.toEpisode(body);
            page.episode = Object.assign({}, page.episode, {
                title: e.title, description: e.description, thumbnail: e.thumbnail,
                contentType: e.contentType, contentUrl: e.contentUrl, seasonNumber: e.seasonNumber,
                episodeNumber: e.episodeNumber, episodeLabel: e.episodeLabel, duration: e.duration
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
                iconName: page.dlSaved ? "delete" : "save-to"
                text: page.dlSaved ? Lang.tr("Remove download") : Lang.tr("Download")
                visible: page.canDownload && !page.dlActive
                onTriggered: page.download()
            },
            Action {
                iconName: "edit"
                text: Lang.tr("Edit")
                visible: page.canManage
                onTriggered: page.edit()
            },
            Action {
                iconName: "delete"
                text: Lang.tr("Delete episode")
                visible: page.canManage
                onTriggered: PopupUtils.open(deleteDialog)
            }
        ]
    }

    Flickable {
        id: scroll
        anchors { top: page.header.bottom; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
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
                // youtube, web view only after tap
                Loader {
                    id: ytLoader
                    anchors.fill: parent
                    active: page.ytStarted
                    sourceComponent: VideoWebView {
                        wrap: true
                        controls: false
                        reportState: true
                        embedUrl: page.episode.contentUrl
                        onReadyChanged: if (ready) setRate(Player.rate)
                        onEndedChanged: if (ended && Player.autoplayNext) page.ctlNext()
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
                                          page.episode.episodeLabel, page.episode.duration]
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
                              : (page.episode ? page.episode.duration : "")
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

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        visible: page.busy
        z: 100
        MouseArea { anchors.fill: parent }
        ActivityIndicator { anchors.centerIn: parent; running: page.busy }
    }

    Component {
        id: removeDialog
        Dialog {
            id: rdlg
            title: Lang.tr("Remove download?")
            text: Lang.tr("This episode will no longer be available offline.")
            Button {
                text: Lang.tr("Remove")
                color: Style.danger
                onClicked: { PopupUtils.close(rdlg); Downloads.remove(page.dlKey); }
            }
            Button { text: Lang.tr("Cancel"); onClicked: PopupUtils.close(rdlg) }
        }
    }

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
