pragma Singleton
import QtQuick 2.7
import "../services/Http.js" as Http

// App-wide reachability. Http reports every request outcome here (wired in Main.qml),
// so a dead network flips the whole UI to its offline face; while offline a slow probe
// keeps checking so the app recovers on its own once the phone is back on a network.
Item {
    id: net

    // Dev switch: flip to true to preview every offline surface without pulling the plug.
    // Ships false; nothing in the app sets it.
    property bool forceOffline: false

    readonly property bool online: !net.forceOffline && net._reachable
    property bool _reachable: true
    property bool _probing: false
    // Launch time, for cold-start grace
    property double _startedAt: Date.now()
    // Last real request success
    property double _lastOkAt: 0
    property double _probeStartedAt: 0

    // status 0 from Http.js is "no response at all", but that also covers our own abort()
    // of a stale feed request, so a failure is confirmed with a probe before flipping.
    onOnlineChanged: {
        // Only hold the cover if the user actually saw it; a silent blip (e.g. at launch)
        // must not leave a "Press to connect" panel waiting on a tab they never looked at.
        net.justReconnected = net.online && net.offlineSeen;
        if (net.online) net.offlineSeen = false;
    }
    // Back online but the offline cover stays until the user taps "Press to connect"
    // (pages reload behind it meanwhile). Cleared by acknowledgeReconnect().
    property bool justReconnected: false
    // Set by OfflineState while it is on screen during an outage.
    property bool offlineSeen: false
    function acknowledgeReconnect() { net.justReconnected = false; }
    function report(reachable) {
        if (net.forceOffline) return;
        if (reachable) { net._lastOkAt = Date.now(); net._reachable = true; return; }
        if (!net._reachable || net._probing) return;
        net.probe();
    }

    // Any HTTP answer proves connectivity, so the status code itself doesn't matter.
    property var _probeXhr: null
    // manual = user tapped Try again: keep probing for a while instead of one shot.
    function probe(manual, again) {
        if (net.forceOffline) return;
        // Woke from a freeze: the pool was just reset, so a probe still "in flight" is dead.
        if (Http.heartbeat()) net._forgetProbe();
        if (manual && !again) {
            net._burstUntil = Date.now() + 20000;
            burstTimer.stop();
            // A wedged pool would queue Try again behind dead requests forever; start clean.
            if (!net._reachable) net._dropPool();
        }
        // Never abort a running probe: the first one after a reconnect is mid-handshake,
        // and restarting it just pays the cold DNS/TLS cost again.
        if (net._probing) return;
        net._probing = true;
        net._probeStartedAt = Date.now();
        var xhr = new XMLHttpRequest();
        net._probeXhr = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (net._probeXhr !== xhr) return;   // timed out already
            net._finishProbe(xhr.status !== 0);
        };
        try {
            // Cache-bust so a retry never gets a cached error. It does NOT force a new
            // connection (measured); Http.resetConnections() is what does that.
            xhr.open("HEAD", Config.baseUrl + (manual ? "?_=" + Date.now() : ""));
            xhr.send();
            // Offline: the first answer after a reconnect took ~6s on device, and cutting it at
            // 3s restarted the cold handshake forever. Online keeps 3s to spot a drop fast.
            probeTimeout.interval = !net._reachable ? 15000
                                  : net._confirming || Date.now() - net._startedAt < 15000 ? 8000 : 3000;
            probeTimeout.restart();
        } catch (e) {
            net._finishProbe(false);
        }
    }

    // Fresh connection pool; any probe in flight rode the old one and will never answer.
    function _dropPool() {
        Http.resetConnections();
        net._forgetProbe();
    }
    function _forgetProbe() {
        probeTimeout.stop();
        net._probing = false;
        net._probeXhr = null;
    }

    function _finishProbe(ok) {
        probeTimeout.stop();
        net._probing = false;
        net._probeXhr = null;
        // Real success during probe wins
        ok = ok || net._lastOkAt >= net._probeStartedAt;
        // One stalled probe right after a reconnect flipped us back offline (next one
        // answered in 87ms); confirm with a second probe before leaving online.
        if (!ok && net._reachable && !net._confirming) {
            net._confirming = true;
            net.probe();
            return;
        }
        net._confirming = false;
        net._reachable = ok;
        if (!net._reachable && Date.now() < net._burstUntil) burstTimer.restart();
        else net._burstUntil = 0;
    }

    property double _burstUntil: 0
    property bool _confirming: false
    Timer {
        id: burstTimer
        interval: 1500
        repeat: false
        onTriggered: net.probe(true, true)
    }

    // QML's XMLHttpRequest ignores its own `timeout` when the connection stalls rather than
    // being refused (measured against an unroutable host: no ontimeout in 30s, so a probe hung
    // forever, _probing stayed true, and every later probe no-opped - the app never noticed it
    // was offline). Time the probe here instead. A HEAD answers in well under a second on any
    // live connection, so this only has to outlast a slow handshake.
    Timer {
        id: probeTimeout
        interval: 3000
        repeat: false
        onTriggered: {
            if (!net._probing) return;
            // Just mute it, don't abort(): aborting a stalled request froze the UI for ~4s
            // on device, and abort() doesn't free its connection slot anyway.
            net._probeXhr = null;
            // A hang (not a fast failure) on a dead pooled socket: drop the pool once it's
            // confirmed, so stuck requests can't fill all 6 slots and wedge us offline.
            if (!net._reachable || net._confirming) Http.resetConnections();
            net._finishProbe(false);
        }
    }

    // Times out hung requests (Qt's XHR timeout never fires); see Http.sweep().
    Timer {
        interval: 1000
        repeat: true
        running: net.pending > 0
        onTriggered: Http.sweep()
    }

    // Wake detector: keeps Http's heartbeat fresh, and re-checks reachability right after a
    // freeze (phone asleep). The pool reset itself happens inside Http.heartbeat().
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: if (Http.heartbeat()) { net._forgetProbe(); net.probe(); }
    }

    // Offline probes now run up to 15s themselves, so poll again soon after one ends.
    Timer {
        interval: 5000
        repeat: true
        running: !net.online && !net.forceOffline
        onTriggered: net.probe()
    }

    // Requests currently waiting for an answer (fed by Http.setPendingHandler in Main.qml).
    property int pending: 0

    // A dropped connection otherwise stays invisible until a request hits its own 15s timeout,
    // so the spinner outlives the network. While anything is pending, probe: the probe answers
    // in well under a second on a live link, so a slow-but-alive network is left alone and only
    // a real outage flips us offline early.
    Timer {
        interval: 1200
        repeat: true
        running: net.pending > 0 && net._reachable && !net.forceOffline
        onTriggered: net.probe()
    }
}
