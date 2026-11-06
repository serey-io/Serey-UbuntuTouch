.pragma library
.import "Http.js" as Http
.import "Mappers.js" as M

// Next API route; aggregates every community (no backend equivalent)
var GLOBAL_URL = "https://serey.io/api";

function _dedupe(rows) {
    var seen = {}, out = [];
    for (var i = 0; i < rows.length; i++) {
        var k = String(rows[i].id);
        if (seen[k]) continue;
        seen[k] = true;
        out.push(rows[i]);
    }
    return out;
}

// hide all premium episodes (access_type 2), unlocked or not
function _playable(rows) {
    return rows.filter(function (e) { return e.accessType !== 2 && !e.isLocked; });
}

// Season number -> access_type, port of web seasonAccessType: synced rows don't count, mixed is public
function seasonAccess(episodes) {
    var by = {};
    for (var i = 0; i < episodes.length; i++) {
        var e = episodes[i];
        if (e.sourceId) continue;
        var s = String(e.seasonNumber);
        if (!(s in by)) by[s] = e.accessType;
        else if (by[s] !== e.accessType) by[s] = 1;
    }
    return by;
}

// access_type to write for a season; locked rows still carry access_type
function accessForSeason(baseUrl, communityId, season, onOk, onErr) {
    return Http.get(baseUrl, "/podcast/list", { community_id: communityId, season_number: season, limit: 200 }, "",
        function (data) {
            var by = seasonAccess((data.podcasts || []).map(M.toEpisode));
            onOk(by[String(season)] || 1);
        }, onErr);
}

// All episodes of one community; API pages at 200
function listAll(baseUrl, communityId, token, onOk, onErr) {
    var all = [];
    var req = { xhr: null, abort: function () { if (this.xhr) this.xhr.abort(); this.xhr = null; } };
    function page(n) {
        req.xhr = Http.get(baseUrl, "/podcast/list", { community_id: communityId, limit: 200, page: n }, token,
            function (data) {
                all = all.concat(data.podcasts || []);
                var total = (data.pagination && data.pagination.total_pages) || 1;
                if (n < total) page(n + 1);
                else { req.xhr = null; onOk(_playable(_dedupe(all).map(M.toEpisode))); }
            }, onErr);
    }
    page(1);
    return req;
}

// Global tab: latest episodes from every community, newest first
function listGlobal(token, onOk, onErr) {
    return Http.get(GLOBAL_URL, "/podcast/global", {}, token, function (data) {
        var rows = [];
        var comms = data.communities || [];
        for (var i = 0; i < comms.length; i++) {
            var eps = comms[i].episodes || [];
            for (var j = 0; j < eps.length; j++) {
                var e = M.toEpisode(eps[j]);
                e.communityTitle = comms[i].title || "";
                e.communityDns = comms[i].dns || "";
                e.communityIcon = comms[i].icon_url || "";
                rows.push(e);
            }
        }
        rows = _playable(_dedupe(rows));
        rows.sort(function (a, b) { return a.createdAt < b.createdAt ? 1 : a.createdAt > b.createdAt ? -1 : 0; });
        // shortcut: newest 60 only, keeps the list light; add paging if users want older
        onOk(rows.slice(0, 60));
    }, onErr);
}

// Ordered season numbers present in the list
function seasons(episodes) {
    var seen = {}, out = [];
    for (var i = 0; i < episodes.length; i++) {
        var s = episodes[i].seasonNumber;
        if (seen[s]) continue;
        seen[s] = true;
        out.push({ number: s, title: episodes[i].seasonTitle });
    }
    out.sort(function (a, b) { return a.number - b.number; });
    return out;
}

// Web link that opens this episode
function shareUrl(ep, fallbackDns) {
    var dns = ep.communityDns || fallbackDns || "serey.io";
    return "https://" + dns + "/podcast?episode=" + encodeURIComponent(ep.slug || ep.permlink || String(ep.id));
}

// Port of web buildEpisodePayload
function payload(form, communityId) {
    var num = function (v) { var n = parseInt(String(v || "").replace(/\D/g, ""), 10); return n > 0 ? n : null; };
    var type = form.contentType || "audio";
    return {
        community_id: Number(communityId),
        title: String(form.title || "").trim(),
        description: String(form.description || "").trim() || null,
        content_type: type,
        content_url: String(form.contentUrl || "").trim(),
        thumbnail_url: form.thumbnail || null,
        is_video: type === "link" ? null : type === "video",
        duration: num(form.duration),
        episode_number: num(form.episode),
        season_number: num(form.season) || 1,
        season_title: form.seasonTitle ? String(form.seasonTitle).trim() || null : null,
        tags: null,
        access_type: form.accessType || 1
    };
}

function create(baseUrl, body, token, onOk, onErr) {
    return Http.post(baseUrl, "/podcast/create", body, token, onOk, onErr);
}

function update(baseUrl, id, body, token, onOk, onErr) {
    return Http.put(baseUrl, "/podcast/update-by-id/" + id, body, token, onOk, onErr);
}

function remove(baseUrl, id, token, onOk, onErr) {
    return Http.delWithBody(baseUrl, "/podcast/delete-by-id/" + id, { deleted_reason: "Deleted by owner" }, token, onOk, onErr);
}
