.pragma library

// Backend cap on raw body HTML
var MAX_BODY = 280;

// Links web's note composer accepts
var VIDEO_LINK_RE = /^https?:\/\/(?:www\.|m\.|vm\.)?(?:youtube\.com\/(?:watch\?|embed\/|shorts\/)|youtu\.be\/|tiktok\.com\/|facebook\.com\/|fb\.watch\/)\S+$/i;

function isVideoLink(url) {
    return VIDEO_LINK_RE.test(String(url || "").trim());
}

// Web's note clip cap
var MAX_VIDEO_SECONDS = 60;

// Uploaded file (Serey storage), not a platform link
function isDirectVideo(url) {
    return /^https?:\/\//i.test(url || "") && !isVideoLink(url);
}

function _escape(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Plain text -> one <p> per line
function toBody(text) {
    var t = String(text || "").replace(/\r/g, "").trim();
    if (t.length === 0) return "";
    var lines = t.split("\n");
    var out = "";
    for (var i = 0; i < lines.length; i++)
        out += "<p>" + (lines[i].length > 0 ? _escape(lines[i]) : "<br>") + "</p>";
    return out;
}

// Chars left under backend cap
function remaining(text) {
    return MAX_BODY - toBody(text).length;
}

var URL_RE = /((?:https?:\/\/|www\.)[^\s<>"]+[^\s<>".,;:!?)\]'])/gi;

function _href(u) {
    return /^https?:\/\//i.test(u) ? u : "https://" + u;
}

// HTML: wrap bare URLs, skip existing <a>
function linkify(html, color) {
    var parts = String(html || "").split(/(<a\b[^>]*>[\s\S]*?<\/a>|<[^>]+>)/gi);
    for (var i = 0; i < parts.length; i += 2) {
        parts[i] = (parts[i] || "").replace(URL_RE, function (u) {
            var inner = color ? '<font color="' + color + '">' + u + '</font>' : u;
            var href = _href(u).replace(/&amp;/g, "&").replace(/"/g, "%22");
            return '<a href="' + href + '">' + inner + '</a>';
        });
    }
    return parts.join("");
}

// Plain text -> StyledText with links
function linkifyPlain(text, color) {
    return linkify(_escape(text || "").replace(/\n/g, "<br>"), color);
}

var YT_RE = /(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?\S*v=|embed\/|shorts\/)|youtu\.be\/)[A-Za-z0-9_-]{6,}\S*/i;

// First YouTube link in text: {raw, url} or null
function findYouTube(text) {
    var m = YT_RE.exec(String(text || ""));
    return m ? { raw: m[0], url: _href(m[0].replace(/&amp;/g, "&")) } : null;
}

// Text minus one substring, tidied
function removeText(text, raw) {
    var t = String(text || "");
    var i = t.indexOf(raw);
    if (i < 0) return t;
    return (t.substring(0, i) + t.substring(i + raw.length))
        .replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
}

// YouTube thumb, else ""
function videoThumb(url) {
    var m = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/i.exec(url || "");
    return m ? ("https://img.youtube.com/vi/" + m[1] + "/hqdefault.jpg") : "";
}
