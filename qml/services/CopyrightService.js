.pragma library
.import "Http.js" as Http

// Web route: saves to CMS queue, emails team, notifies community owner. Public, no auth.
var SUBMIT_URL = "https://serey.io/api/report-copyright";

// Public link to the reported content, per kind
function contentUrl(post, kind) {
    if (!post || !post.author || !post.permlink) return "";
    if (kind === "video")
        return "https://serey.io/video-component/watch?author=" + post.author + "&permalink=" + post.permlink;
    return "https://serey.io/authors/" + post.author + "/" + post.permlink;
}

function isUrl(s) {
    return /^https?:\/\/[^\s.]+\.[^\s]+$/i.test(String(s || "").trim());
}

function isEmail(s) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(s || "").trim());
}

// --- Owner review (backend scopes by token) ---

// status: "" = all | "open" | "resolved" | "dismissed"
function adminList(baseUrl, token, status, onOk, onErr) {
    return Http.get(baseUrl, "/report-copyright/admin", status ? { status: status } : null, token,
        function (data) { onOk((data && data.data) || []); }, onErr);
}

function adminUpdate(baseUrl, token, id, status, onOk, onErr) {
    return Http.patch(baseUrl, "/report-copyright/admin/" + id, { status: status }, token,
        function (data) { onOk(data || {}); }, onErr);
}

// Serey link -> { author, permlink }; blog or video link, else null
function parseContentLink(link) {
    var s = String(link || "");
    var m = /\/authors\/([^\/?#]+)\/([^\/?#]+)/.exec(s);
    if (!m) {
        var a = /[?&]author=([^&#]+)/.exec(s);
        var p = /[?&]permalink=([^&#]+)/.exec(s);
        if (a && p) m = [null, a[1], p[1]];
    }
    if (!m) return null;
    try { return { author: decodeURIComponent(m[1]), permlink: decodeURIComponent(m[2]) }; }
    catch (e) { return { author: m[1], permlink: m[2] }; }
}

// payload: { contentLink, community, communityId, message, originalLink, email, reporterUsername }
// token optional: signed-in reporter shows as the owner's notification actor
function submit(payload, onOk, onErr, token) {
    var body = {
        content_link: payload.contentLink,
        community: payload.community,
        message: payload.message,
        original_content_link: payload.originalLink
    };
    if (payload.communityId) body.community_id = payload.communityId;
    if (payload.email) body.reporter_email = payload.email;
    // Signed-in reporter's name
    if (payload.reporterUsername) body.reporter_name = payload.reporterUsername;
    return Http.send("POST", SUBMIT_URL, token || null, body,
        function (data) { onOk((data && data.message) || ""); },
        onErr);
}
