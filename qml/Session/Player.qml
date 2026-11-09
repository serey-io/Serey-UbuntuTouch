pragma Singleton
import QtQuick 2.7
import QtMultimedia 5.12
import QtQuick.LocalStorage 2.0
import "../Theme"

// podcast audio player
QtObject {
    id: player

    property var current: null
    property var queue: []
    property int index: -1
    property real rate: 1.0
    property bool autoplayNext: true
    // full player page on screen; hides mini bar
    property var openPage: null
    readonly property bool pageOpen: openPage !== null
    function setPageShown(pg, shown) {
        if (shown) openPage = pg;
        else if (openPage === pg) openPage = null;
    }
    property string error: ""
    // youtube and video episodes play in shared views in Main.qml; the open page lends its stage
    property var yt: null
    property var vid: null
    // set once a video page opens, so the video player is built before the tap
    property bool vidWarm: false
    // only a pause from our buttons counts; youtube may pause itself off-page
    property bool ytUserPaused: false
    property var stage: null
    property var _stageOwner: null
    function setStage(pg, st, shown) {
        if (shown) { _stageOwner = pg; stage = st; }
        else if (_stageOwner === pg) { _stageOwner = null; stage = null; }
    }
    function isYtLink(ep) { return !!ep && ep.contentType === "link" && /(youtube\.com\/(watch|embed|shorts)|youtu\.be\/)/i.test(ep.contentUrl || ""); }
    function isSaved(ep) { return !!ep && Downloads.pathFor(key(ep)).length > 0; }
    // downloaded youtube plays its file natively
    function isYt(ep) { return isYtLink(ep) && !isSaved(ep); }
    function isVideo(ep) { return !!ep && (ep.contentType === "video" || (isYtLink(ep) && isSaved(ep))); }
    // fixed at play(), so a download finishing mid-play doesn't swap players
    property bool _local: false
    readonly property bool ytMode: isYtLink(current) && !_local
    readonly property bool vidMode: !!current && (current.contentType === "video" || (isYtLink(current) && _local))
    // the media object playing the current episode (audio, or the shared video player)
    readonly property var _m: vidMode ? (vid ? vid.media : null) : ytMode ? null : audio

    readonly property bool playing: ytMode ? (!!yt && yt.ready && !yt.paused)
                                           : _seekHold || (!!_m && _m.playbackState === MediaPlayer.PlayingState)
    readonly property bool buffering: ytMode ? (!yt || !yt.ready)
                                             : vidMode && !_m ? true
                                             : !!_m && (_m.status === MediaPlayer.Loading || _m.status === MediaPlayer.Buffering
                                                        || _m.status === MediaPlayer.Stalled)
    // show the target time while the resume seek is pending
    readonly property int position: ytMode ? (yt ? yt.position : 0)
                                    : _m ? (_resumeTo > 0 ? _resumeTo : _seekShow >= 0 ? _seekShow : Math.max(0, _m.position)) : 0
    // media-hub reports junk mid-seek; show the target until it lands
    property int _seekShow: -1
    property Timer _seekShowEnd: Timer { interval: 8000; onTriggered: player._seekShow = -1 }
    readonly property int duration: ytMode ? (yt ? yt.duration : 0) : _m && _m.duration > 0 ? _m.duration : _durHint
    property int _durHint: 0
    property real _resumeStart: 0
    readonly property var rates: [1.0, 1.25, 1.5, 2.0, 0.75]

    property int _resumeTo: 0
    property var _db: null

    function key(ep) { return "podcast-" + (ep ? ep.id : ""); }
    function canPlay(ep) { return !!ep && (ep.contentType === "audio" || ep.contentType === "video" || isYtLink(ep)) && !ep.isLocked && !!(ep.contentUrl || Downloads.pathFor(key(ep))); }
    function isCurrent(ep) { return !!ep && !!current && String(current.id) === String(ep.id); }
    function sourceFor(ep) { return Downloads.pathFor(key(ep)) || ep.contentUrl || ""; }

    // at: start position (ms), else saved resume point
    function play(ep, list, at, dur) {
        if (!canPlay(ep)) return;
        if (isCurrent(ep)) { if (!playing) toggle(); return; }
        _save();
        // mute before the view is torn down
        if (yt && !isYt(ep)) yt.stop();
        // media-hub ignores a cleared source and keeps playing; only destroying the player stops it
        if (!isVideo(ep)) { if (vid) vid.source = ""; vidWarm = false; }
        if (isYt(ep) || isVideo(ep)) _dropAudio();
        _local = isSaved(ep);
        current = ep;
        queue = (list && list.length) ? list : [ep];
        index = 0;
        for (var i = 0; i < queue.length; i++) if (String(queue[i].id) === String(ep.id)) { index = i; break; }
        error = "";
        _seekHold = false;
        _seekShow = -1;
        _resumeStart = Date.now();
        _durHint = dur > 0 ? dur : 0;
        _resumeTo = isYt(ep) ? 0 : at > 0 ? at : _loadPos(key(ep));
        ytUserPaused = false;
        _log("play " + (ep.title || ep.id) + " at=" + at);
        if (isYt(ep)) return;
        // Main.qml builds the shared video player, then calls _feedVid
        if (isVideo(ep)) { vidWarm = true; _feedVid(); return; }
        _ensureAudio();
        audio.source = sourceFor(ep);
        audio.play();
    }
    function _feedVid() {
        if (!vid || !vidMode) return;
        var s = sourceFor(current);
        if (vid.source === s) return;
        vid.media.playbackRate = rate;
        vid.source = s;
    }
    function toggle() {
        if (playing) { pause(); return; }
        if (ytMode) { ytUserPaused = false; if (yt) yt.play(); }
        else if (vidMode) { if (vid) vid.togglePause(); }
        else if (current) audio.play();
    }
    function pause() {
        if (!playing) return;
        var held = _seekHold;
        _seekHold = false;
        if (ytMode) { ytUserPaused = true; yt.pause(); }
        else if (vidMode) { if (vid && !held) vid.togglePause(); }
        else audio.pause();
        _save();
    }
    function stop() {
        _save(); _seekHold = false; _resumeTo = 0; _seekShow = -1;
        if (yt) yt.stop();
        if (vid) vid.source = "";
        vidWarm = false;
        _dropAudio();
        current = null; queue = []; index = -1;
    }
    function seekTo(ms) {
        _resumeTo = 0;
        if (ytMode) { if (yt) yt.seekTo(Math.max(0, ms)); }
        else if (_m) {
            var t = Math.max(0, Math.min(ms, duration > 0 ? duration : ms));
            _seekShow = t;
            _seekShowEnd.restart();
            _m.seek(t);
        }
    }
    function seekBy(ms) { seekTo(position + ms); }
    onRateChanged: {
        if (yt) yt.setRate(rate);
        if (vid) vid.media.playbackRate = rate;
    }
    function cycleRate() { var i = rates.indexOf(rate); rate = rates[(i + 1) % rates.length]; }

    function hasNext() { return _nextIndex(1) >= 0; }
    function hasPrev() { return _nextIndex(-1) >= 0; }
    function next() { var i = _nextIndex(1); if (i >= 0) play(queue[i], queue); }
    function prev() {
        // restart first, like most players
        if (position > 5000 || !hasPrev()) { seekTo(0); return; }
        play(queue[_nextIndex(-1)], queue);
    }
    function _nextIndex(dir) {
        for (var i = index + dir; i >= 0 && i < queue.length; i += dir) if (canPlay(queue[i])) return i;
        return -1;
    }

    // labels built here so they translate; ep.duration may be "45 min" from older downloads
    function episodeLabel(ep) {
        var n = ep ? ep.episodeNumber : 0;
        return n ? Lang.tr("Ep. %1").arg(n < 10 ? "0" + n : String(n)) : "";
    }
    function durationLabel(ep) {
        var m = parseInt(String((ep && ep.duration) || "").replace(/\D/g, ""), 10);
        return m > 0 ? Lang.tr("%1 min").arg(m) : "";
    }

    function fmt(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
        var pad = function (n) { return n < 10 ? "0" + n : String(n); };
        return (h > 0 ? h + ":" + pad(m) : String(m)) + ":" + pad(sec);
    }

    // resume points
    function _open() {
        if (!_db) {
            _db = LocalStorage.openDatabaseSync("SereyPodcast", "1.0", "Podcast resume points", 100000);
            _db.transaction(function (tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS progress(k TEXT PRIMARY KEY, pos INTEGER, dur INTEGER)");
            });
        }
        return _db;
    }
    function _loadPos(k) {
        var out = 0;
        try {
            _open().readTransaction(function (tx) {
                var rs = tx.executeSql("SELECT pos, dur FROM progress WHERE k = ?", [k]);
                if (rs.rows.length > 0) {
                    var r = rs.rows.item(0);
                    // near the end counts as finished
                    out = (r.dur > 0 && r.pos > r.dur - 10000) ? 0 : r.pos;
                }
            });
        } catch (e) { console.log("Player load error: " + e); }
        return out;
    }
    function _savePos(k, pos, dur) {
        try {
            _open().transaction(function (tx) {
                tx.executeSql("INSERT OR REPLACE INTO progress(k, pos, dur) VALUES(?, ?, ?)", [k, pos, dur]);
            });
        } catch (e) { console.log("Player save error: " + e); }
    }
    function _save() { if (current && position > 0) _savePos(key(current), position, duration); }
    // 0..1 listened, for list rows
    function progressFor(ep) {
        var out = 0;
        try {
            _open().readTransaction(function (tx) {
                var rs = tx.executeSql("SELECT pos, dur FROM progress WHERE k = ?", [key(ep)]);
                if (rs.rows.length > 0 && rs.rows.item(0).dur > 0) out = rs.rows.item(0).pos / rs.rows.item(0).dur;
            });
        } catch (e) { }
        return out;
    }

    function _ended() {
        if (!current) return;
        _savePos(key(current), duration, duration);
        if (autoplayNext && hasNext()) next();
    }

    // shortcut: debug log for the resume jump, remove once fixed
    function _log(m) {
        console.log("[pod] +" + (Date.now() - _resumeStart) + "ms " + m
                    + (_m ? " | pos=" + _m.position + " state=" + _m.playbackState + " status=" + _m.status
                            + " seekable=" + _m.seekable : "") + " vid=" + vidMode
                    + " resumeTo=" + _resumeTo + " hold=" + _seekHold);
    }
    function _applyResume() {
        if (_m && _resumeTo > 0 && _m.seekable) { _log("seek -> " + _resumeTo); _m.seek(_resumeTo); _seekAt = Date.now(); }
    }
    property real _seekAt: 0
    // media-hub says "playing" ~3s before audio starts, drops seeks until then, and ignores mute.
    // So poll: the moment real audio starts, pause, seek, and play once it lands.
    property bool _seekHold: false
    property Timer _probe: Timer {
        interval: 100
        repeat: true
        running: player._resumeTo > 0 && !!player._m
        onTriggered: player._probeTick()
    }
    function _probeTick() {
        var m = _m;
        var p = m.position;
        if (p >= _resumeTo - 3000) { _log("probe landed at " + p); _resumeTo = 0; return; }
        // pipeline still loading
        if (p < 0) return;
        if (!_seekHold && m.playbackState === MediaPlayer.PlayingState && Date.now() - _seekAt > 1500) {
            _log("probe: started at " + p + ", pause + seek");
            _seekHold = true;
            m.pause();
            m.seek(_resumeTo);
            _seekAt = Date.now();
        } else if (_seekHold && Date.now() - _seekAt > 2000) {
            _log("probe: paused seek didn't land, play");
            _seekHold = false;
            m.play();
        }
    }
    on_ResumeToChanged: {
        if (_resumeTo > 0 || !_seekHold) return;
        _seekHold = false;
        if (_m) _m.play();
    }
    // keep retrying until the seek lands
    function _checkResume() {
        if (_resumeTo <= 0) return;
        if (!_m) return;
        // give up after 10s so it never hangs
        if (_m.position >= _resumeTo - 3000 || Date.now() - _resumeStart > 10000) { _log("resume done"); _resumeTo = 0; }
        else if (_m.position > 0 && Date.now() - _seekAt > 1500) _applyResume();
    }

    // created on first play; media backend start is slow
    property var audio: null
    function _dropAudio() { if (!audio) return; var a = audio; audio = null; a.stop(); a.destroy(); }
    function _ensureAudio() { if (!audio) audio = _audioComp.createObject(player); return audio; }

    property Component _audioComp: Component {
      Audio {
        playbackRate: player.rate
        // shortcut: media-hub reports the video page's cleared source ("uri  ") here, drop if hub gets per-player sessions
        onError: if (errorString.indexOf("uri  ") < 0) player.error = errorString || Lang.tr("Couldn't play this episode.")
      }
    }

    // resume + autoplay for whichever media is current
    property Connections _mediaConn: Connections {
        target: player._m
        ignoreUnknownSignals: true
        function onSeekableChanged() { player._log("seekable"); player._applyResume(); }
        // media-hub drops seeks sent before playback starts
        function onPositionChanged() {
            player._checkResume();
            // 5s slack: video seeks snap to a keyframe
            if (player._seekShow >= 0 && Math.abs(player._m.position - player._seekShow) < 5000) {
                player._log("seek landed, target " + player._seekShow);
                player._seekShow = -1;
            }
        }
        function onPlaybackStateChanged() { player._log("state"); if (player._m.playbackState === MediaPlayer.PlayingState) player._applyResume(); }
        function onStatusChanged() {
            var st = player._m.status;
            player._log("status");
            if (st === MediaPlayer.Loaded || st === MediaPlayer.Buffered) player._applyResume();
            if (st === MediaPlayer.EndOfMedia) player._ended();
        }
    }

    // the app may be suspended or closed before the next tick
    property Connections _appState: Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state !== Qt.ApplicationActive) player._save(); }
    }

    property Timer _saver: Timer {
        interval: 5000
        repeat: true
        running: player.playing
        onTriggered: player._save()
    }
}
