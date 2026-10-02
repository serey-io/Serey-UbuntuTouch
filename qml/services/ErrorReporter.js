.pragma library
.import "Http.js" as Http

// Server-error alerts: Http.js hands us every 5xx / non-JSON reply, we post a short report to
// serey-api, which dedupes across devices and forwards to the Delta Chat group.
// Never sends bodies, tokens or query strings.

var REPORT_PATH = "/ubuntu-app/report/error";

// First hit alerts at once; everything else only shows up in the server's 10 min digest.
var CRITICAL = [
    "/auth/login", "/auth/2fa/verify-login",
    "/accounts/create-account", "/registration/anonymous/",
    "/general/get-communities",
    "/serey-web/list-by-", "/serey-web/list-gallery-post-by-", "/serey-web/list-drum-post-by-feed",
    "/serey-web/details-by-permlink-and-author",
    "/video-component/list-all-videos-by-author", "/video-component/detail-video-post",
    "/serey-web/create-or-update-post", "/serey-web/create-or-update-comment",
    "/vote/vote", "/vote/flag",
    "/subscription/crypto/", "/subscription/stripe/",
    "/notification/register-push-token",
    "/upload/"
];

// Routes whose last segment is a username/id; collapsed so alerts group and stay anonymous.
var PARAM_PREFIXES = [
    "/accounts/details-by-username/", "/accounts/check-existing-username/",
    "/community-subscriber/pagination/", "/landing-page-v2/get-by-community/",
    "/landing-page/get-landing-page-by-community/", "/landing-page/get-by-community/",
    "/landing-page/delete/", "/premium-community-setting/get-by-community-id/",
    "/notification/update-read-by-id/", "/notification/get-by-id/",
    "/community/list-community-manager-by-community-id/",
    "/serey-web/admin-delete-post-or-comment/", "/report-copyright/admin/",
    "/ubuntu-app/report/"
];

var THROTTLE_MS = 5 * 60 * 1000;   // same route+status at most once per 5 min per device
var SESSION_CAP = 20;              // a broken server shouldn't turn into a phone-side flood

var _lastSent = {};
var _sentCount = 0;

function _routeOf(baseUrl, url) {
    var path;
    if (url.charAt(0) === "/") path = url;
    else if (url.indexOf(baseUrl) === 0) path = url.substring(baseUrl.length);
    else return null;   // third-party hosts (AI detection, copyright) aren't ours to alert on
    path = path.split("?")[0].split("#")[0];
    for (var i = 0; i < PARAM_PREFIXES.length; i++) {
        var p = PARAM_PREFIXES[i];
        if (path.indexOf(p) === 0 && path.length > p.length) return p + ":param";
    }
    // Unknown route with an id-like segment: still never leak it.
    return path.replace(/\/[^\/]*\d[^\/]*/g, function (seg) {
        return /^\/(2fa|[a-z]+(-[a-z0-9]+)+)$/.test(seg) ? seg : "/:param";
    }).substring(0, 200);
}

function _isCritical(path) {
    if (path === "/video-component/") return true;   // community video feed
    for (var i = 0; i < CRITICAL.length; i++)
        if (path.indexOf(CRITICAL[i]) === 0) return true;
    return false;
}

function report(baseUrl, token, err, appVersion) {
    if (!err || !err.url) return;
    // Server faults only: 5xx, or a 2xx we couldn't read. A 4xx error page isn't an outage.
    var st = err.status;
    if (!(st >= 500 || (st >= 200 && st < 300))) return;
    // Never report our own reporting; checked on the raw URL, before the :param collapse.
    if (err.url.indexOf(REPORT_PATH) !== -1) return;
    var path = _routeOf(baseUrl, err.url);
    if (!path) return;

    var key = err.method + " " + path + " " + err.status;
    var now = Date.now();
    if (_lastSent[key] && now - _lastSent[key] < THROTTLE_MS) return;
    if (_sentCount >= SESSION_CAP) return;
    _lastSent[key] = now;
    _sentCount++;

    // Login/signup alerts stay anonymous: no token, so the server can't name the user.
    var anonymous = path.indexOf("/auth/") === 0 || path.indexOf("/accounts/create-account") === 0
            || path.indexOf("/registration/") === 0;
    Http.send("POST", baseUrl + REPORT_PATH, anonymous ? null : (token || null), {
        method: err.method,
        path: path,
        status: err.status,
        message: String(err.message || "").substring(0, 280),
        app_version: appVersion || "",
        critical: _isCritical(path)
    }, function () { }, function () { }, 10000);
}
