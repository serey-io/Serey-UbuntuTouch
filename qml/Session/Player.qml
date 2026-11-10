pragma Singleton
import QtQuick 2.7
import QtMultimedia 5.12
import QtQuick.LocalStorage 2.0
import Qt.labs.settings 1.0
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

    readonly property bool playing: !!audio && audio.playbackState === Audio.PlayingState
    // media-hub stays in Loading for the whole playback, so moving playback counts as loaded
    readonly property bool buffering: !!audio && (_seekTarget >= 0
                                                  || ((audio.status === Audio.Loading || audio.status === Audio.Buffering
                                                       || audio.status === Audio.Stalled) && !(playing && _pos > 0)))
    // a just-requested seek shows at once; media-hub reports the new position late
    property int _seekTarget: -1
    // copies fed from change signals: media-hub briefly reports negative garbage, and binding to its duration loops
    property int _pos: 0
    property int _dur: 0
    readonly property int position: _seekTarget >= 0 ? _seekTarget : _resumeTo > 0 ? _resumeTo : _pos
    readonly property int duration: _dur
    readonly property var rates: [1.0, 1.25, 1.5, 2.0, 0.75]

    property int _resumeTo: 0
    property var _db: null

    // [podcast] trace for device debugging (journalctl --user); ids and types only, no URLs
    function log(m) { console.log("[podcast] " + m); }
    function key(ep) { return "podcast-" + (ep ? ep.id : ""); }
    // audio only: on the phone a video file with no video surface hangs media-hub
    function canPlay(ep) { return !!ep && ep.contentType === "audio" && !ep.isLocked && !!(ep.contentUrl || Downloads.pathFor(key(ep))); }
    function isCurrent(ep) { return !!ep && !!current && String(current.id) === String(ep.id); }
    function sourceFor(ep) { return Downloads.pathFor(key(ep)) || ep.contentUrl || ""; }

    // starts at the saved resume point
    function play(ep, list) {
        if (!canPlay(ep)) return;
        if (isCurrent(ep)) { audio.play(); return; }
        _save();
        _seekTarget = -1;
        _pos = 0;
        _dur = 0;
        current = ep;
        queue = (list && list.length) ? list : [ep];
        index = 0;
        for (var i = 0; i < queue.length; i++) if (String(queue[i].id) === String(ep.id)) { index = i; break; }
        error = "";
        _resumeTo = _loadPos(key(ep));
        log("audio play ep=" + ep.id + " resume=" + _resumeTo);
        _resumeMuted = _resumeTo > 0;
        _rateChecked = false;
        _resumeGiveUp.restart();
        _ensureAudio();
        audio.source = sourceFor(ep);
        audio.play();
    }
    function toggle() { if (playing) pause(); else if (current) audio.play(); }
    function pause() { if (playing) { audio.pause(); _save(); } }
    function stop() { log("audio stop"); _save(); _seekTarget = -1; _resumeTo = 0; _pos = 0; _dur = 0; if (audio) { audio.stop(); audio.source = ""; } current = null; queue = []; index = -1; }
    function seekTo(ms) {
        if (!audio) { _resumeTo = 0; return; }
        var t = Math.max(0, Math.min(ms, duration > 0 ? duration : ms));
        _seekTarget = t;
        _resumeTo = 0;
        log("audio seek " + t);
        _seekTries = 0;
        audio.seek(t);
        _seekRetry.restart();
    }
    function seekBy(ms) { seekTo(position + ms); }
    function cycleRate() {
        var i = rates.indexOf(rate);
        rate = rates[(i + 1) % rates.length];
        if (audio && playing) Qt.callLater(function () { player.checkRate(audio.playbackRate); });
    }
    // media-hub ignores playbackRate; once seen, hide speed for native playback
    property bool rateSupported: true
    property bool _rateChecked: false
    function checkRate(actual) {
        if (rate === 1 || Math.abs(actual - rate) < 0.01) return;
        log("rate unsupported, asked " + rate + " got " + actual);
        rateSupported = false;
        rate = 1.0;
        Toast.show(Lang.tr("Playback speed isn't supported on this device."));
    }

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
        if (dur > 0) { _progress[k] = Math.min(1, pos / dur); progressRev++; }
    }
    // key -> 0..1 listened, for list rows; read once at start (not inside a binding), kept current by _savePos
    property var _progress: ({})
    property int progressRev: 0
    function progressOf(ep) { return _progress[key(ep)] || 0; }
    Component.onCompleted: {
        var m = {};
        try {
            _open().readTransaction(function (tx) {
                var rs = tx.executeSql("SELECT k, pos, dur FROM progress WHERE dur > 0");
                for (var i = 0; i < rs.rows.length; i++) m[rs.rows.item(i).k] = Math.min(1, rs.rows.item(i).pos / rs.rows.item(i).dur);
            });
        } catch (e) { console.log("Player progress error: " + e); }
        _progress = m;
    }
    function _save() { if (current && position > 0) _savePos(key(current), position, duration); }
    // resume points for video episodes, which play outside this player
    function resumePoint(ep) { return ep ? _loadPos(key(ep)) : 0; }
    function savePoint(ep, pos, dur) { if (ep && pos > 0) _savePos(key(ep), pos, dur); }

    // silent until the resume seek lands, so the first seconds don't play; toggled so media-hub's new session gets it
    property bool _resumeMuted: false
    function _mute(on) { if (!audio) return; audio.muted = !on; audio.muted = on; }
    function _unmuteIfSettled() { if (_resumeMuted && _resumeTo <= 0 && _seekTarget < 0) { _resumeMuted = false; _mute(false); } }
    on_ResumeToChanged: _unmuteIfSettled()
    on_SeekTargetChanged: _unmuteIfSettled()
    // media-hub never emits seekableChanged or a Loaded status, so also try once playing with a length
    function _applyResume() {
        if (audio && _resumeTo > 0 && (audio.seekable || (audio.playbackState === Audio.PlayingState && audio.duration > 0))) {
            seekTo(_resumeTo);
        }
    }

    // created on first play; media backend start is slow
    property var audio: null
    function _ensureAudio() { if (!audio) audio = _audioComp.createObject(player); return audio; }

    property Component _audioComp: Component {
      Audio {
        playbackRate: player.rate
        // default 1s ticks make the seek bar step
        notifyInterval: 500
        onSeekableChanged: player._applyResume()
        onDurationChanged: {
            if (duration > 0) player._dur = duration;
            player._applyResume();
        }
        onPlaybackStateChanged: {
            player.log("audio state " + playbackState + " pos=" + player._pos);
            if (playbackState !== Audio.PlayingState) return;
            if (player._resumeMuted) player._mute(true);
            player._applyResume();
            if (!player._rateChecked) { player._rateChecked = true; Qt.callLater(function () { if (player.audio) player.checkRate(player.audio.playbackRate); }); }
        }
        onPositionChanged: {
            if (position < 0) return;
            player._pos = position;
            if (player._landed(position)) player._seekTarget = -1;
        }
        onStatusChanged: {
            if (status === Audio.Loaded || status === Audio.Buffered) player._applyResume();
            if (status === Audio.EndOfMedia && player.current) {
                player.log("audio ended ep=" + player.current.id);
                player._savePos(player.key(player.current), player.duration, player.duration);
                if (player.autoplayNext && player.hasNext()) player.next();
            }
        }
        // media-hub reports another player's cleared source ("uri  ") here; not ours to show
        onError: {
            player.log("audio error " + error + " " + errorString);
            if (errorString.indexOf("uri  ") < 0) player.error = errorString || Lang.tr("Couldn't play this episode.");
        }
      }
    }

    // the app may be suspended or closed before the next tick
    property Connections _appState: Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state !== Qt.ApplicationActive) player._save(); }
    }

    // never leave the shown time parked on a resume point that couldn't be applied
    property Timer _resumeGiveUp: Timer {
        interval: 12000
        onTriggered: player._resumeTo = 0
    }

    // media-hub drops a seek sent too soon after play starts: resend until the position lands, then give up
    property int _seekTries: 0
    function _landed(pos) { return _seekTarget >= 0 && pos >= _seekTarget - 1500 && pos <= _seekTarget + 6000; }
    property Timer _seekRetry: Timer {
        interval: 1500
        repeat: true
        onTriggered: {
            if (!player.audio || player._seekTarget < 0 || player._landed(player._pos)) { player._seekTarget = -1; stop(); return; }
            if (++player._seekTries > 5) { player._seekTarget = -1; stop(); return; }
            player.audio.seek(player._seekTarget);
        }
    }

    property Settings _prefs: Settings {
        category: "PodcastPlayer"
        property alias rate: player.rate
        property alias autoplayNext: player.autoplayNext
        property alias rateSupported: player.rateSupported
    }

    property Timer _saver: Timer {
        interval: 5000
        repeat: true
        running: player.playing
        onTriggered: player._save()
    }
}
