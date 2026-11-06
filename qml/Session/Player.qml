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

    readonly property bool playing: !!audio && audio.playbackState === Audio.PlayingState
    readonly property bool buffering: !!audio && (audio.status === Audio.Loading || audio.status === Audio.Buffering
                                                  || audio.status === Audio.Stalled)
    readonly property int position: audio ? audio.position : 0
    readonly property int duration: audio ? audio.duration : 0
    readonly property var rates: [1.0, 1.25, 1.5, 2.0, 0.75]

    property int _resumeTo: 0
    property var _db: null

    function key(ep) { return "podcast-" + (ep ? ep.id : ""); }
    function canPlay(ep) { return !!ep && (ep.contentType === "audio" || ep.contentType === "video") && !ep.isLocked && !!(ep.contentUrl || Downloads.pathFor(key(ep))); }
    function isCurrent(ep) { return !!ep && !!current && String(current.id) === String(ep.id); }
    function sourceFor(ep) { return Downloads.pathFor(key(ep)) || ep.contentUrl || ""; }

    // at: start position (ms), else saved resume point
    function play(ep, list, at) {
        if (!canPlay(ep)) return;
        if (isCurrent(ep)) { audio.play(); return; }
        _save();
        current = ep;
        queue = (list && list.length) ? list : [ep];
        index = 0;
        for (var i = 0; i < queue.length; i++) if (String(queue[i].id) === String(ep.id)) { index = i; break; }
        error = "";
        _resumeTo = at > 0 ? at : _loadPos(key(ep));
        _ensureAudio();
        audio.source = sourceFor(ep);
        audio.play();
    }
    function toggle() { if (playing) pause(); else if (current) audio.play(); }
    function pause() { if (playing) { audio.pause(); _save(); } }
    function stop() { _save(); if (audio) { audio.stop(); audio.source = ""; } current = null; queue = []; index = -1; }
    function seekTo(ms) { if (audio) audio.seek(Math.max(0, Math.min(ms, duration > 0 ? duration : ms))); }
    function seekBy(ms) { seekTo(position + ms); }
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

    function _applyResume() {
        if (audio && _resumeTo > 0 && audio.seekable) { audio.seek(_resumeTo); _resumeTo = 0; }
    }

    // created on first play; media backend start is slow
    property var audio: null
    function _ensureAudio() { if (!audio) audio = _audioComp.createObject(player); return audio; }

    property Component _audioComp: Component {
      Audio {
        playbackRate: player.rate
        onSeekableChanged: player._applyResume()
        onStatusChanged: {
            if (status === Audio.Loaded || status === Audio.Buffered) player._applyResume();
            if (status === Audio.EndOfMedia && player.current) {
                player._savePos(player.key(player.current), player.duration, player.duration);
                if (player.autoplayNext && player.hasNext()) player.next();
            }
        }
        onError: player.error = errorString || Lang.tr("Couldn't play this episode.")
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
