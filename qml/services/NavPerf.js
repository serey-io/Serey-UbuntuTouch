.pragma library
// Temp [navperf] timings for the My Feed <-> Homepage round trip; enabled from Main.qml.

var enabled = false;
var _marks = {};

function mark(name) { _marks[name] = Date.now(); }

// ms since mark(name), -1 if never marked
function since(name) { return _marks[name] ? Date.now() - _marks[name] : -1; }

function log(msg) { if (enabled) console.log("[navperf] " + msg); }
