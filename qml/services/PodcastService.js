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

// onOk(seasonTitle) to write for a season
function seasonTitle(baseUrl, communityId, season, onOk, onErr) {
    return Http.get(baseUrl, "/podcast/list", { community_id: communityId, season_number: season, limit: 200 }, "",
        function (data) {
            var eps = (data.podcasts || []).map(M.toEpisode);
            var title = "";
            for (var i = 0; i < eps.length && !title; i++) title = eps[i].seasonTitle;
            onOk(title);
        }, onErr);
}

// Does a platform have any episode the app would show
function hasEpisodes(baseUrl, communityId, onOk, onErr) {
    return Http.get(baseUrl, "/podcast/list", { community_id: communityId, limit: 50 }, "", function (data) {
        onOk(_playable((data.podcasts || []).map(M.toEpisode)).length > 0);
    }, onErr);
}

// Every episode row of one community; API pages at 200
function _listRows(baseUrl, communityId, token, onOk, onErr) {
    var all = [];
    var req = { xhr: null, abort: function () { if (this.xhr) this.xhr.abort(); this.xhr = null; } };
    function page(n) {
        req.xhr = Http.get(baseUrl, "/podcast/list", { community_id: communityId, limit: 200, page: n }, token,
            function (data) {
                all = all.concat(data.podcasts || []);
                var total = (data.pagination && data.pagination.total_pages) || 1;
                if (n < total) page(n + 1);
                else { req.xhr = null; onOk(_dedupe(all).map(M.toEpisode)); }
            }, onErr);
    }
    page(1);
    return req;
}

function listAll(baseUrl, communityId, token, onOk, onErr) {
    return _listRows(baseUrl, communityId, token, function (rows) { onOk(_playable(rows)); }, onErr);
}

// Seasons saved without episodes (podcast_theme.extra_seasons)
function savedSeasons(baseUrl, communityId, onOk, onErr) {
    return Http.get(baseUrl, "/general/get-communities", {}, "", function (data) {
        var found = null;
        function walk(nodes) {
            for (var i = 0; i < nodes.length && !found; i++) {
                if (String(nodes[i].id) === String(communityId)) found = nodes[i];
                else walk(nodes[i].child_communities || []);
            }
        }
        ["globals", "locals", "foreigns", "independents"].forEach(function (g) { walk(data[g] || []); });
        // the save replaces the list, so an unknown list must never read as empty
        if (!found || !("podcast_theme" in found)) { onErr({ message: "Couldn't load seasons." }); return; }
        onOk((found.podcast_theme && found.podcast_theme.extra_seasons) || []);
    }, onErr);
}

// Union by number, sorted; port of web mergeSavedSeasons
function mergeSeasons(seasons, extra) {
    var by = {}, out = [];
    seasons.concat(extra).forEach(function (s) {
        var n = Number(s.number);
        if (!by[n]) { by[n] = { number: n, title: s.title || "" }; out.push(by[n]); }
        else if (!by[n].title && s.title) by[n].title = s.title;
    });
    out.sort(function (a, b) { return a.number - b.number; });
    return out;
}

// Season number -> true when all its episodes are premium; port of web seasonAccessType: synced rows don't count, mixed is public
function premiumSeasons(rows) {
    var by = {}, out = {};
    rows.forEach(function (e) {
        if (!e.sourceId) by[e.seasonNumber] = by[e.seasonNumber] !== false && e.accessType === 2;
    });
    Object.keys(by).forEach(function (n) { if (by[n]) out[n] = true; });
    return out;
}

// onOk(publicSeasons, saved, premium); locked rows still carry access_type
function loadSeasons(baseUrl, communityId, onOk, onErr) {
    savedSeasons(baseUrl, communityId, function (saved) {
        _listRows(baseUrl, communityId, "", function (rows) {
            var premium = premiumSeasons(rows);
            var open = mergeSeasons(seasons(rows), saved).filter(function (s) { return !premium[s.number]; });
            onOk(open, saved, premium);
        }, onErr);
    }, onErr);
}

// shortcut: the list read is cached 60s on the server, so a season added elsewhere in that window can drop; needs a save-one-season API to fix
function addSeason(baseUrl, communityId, token, season, known, onOk, onErr) {
    savedSeasons(baseUrl, communityId, function (saved) {
        var next = mergeSeasons(mergeSeasons(saved, known), [season]);
        Http.patch(baseUrl, "/community/update-podcast-theme", { community_id: Number(communityId), extra_seasons: next }, token,
            function (data) { onOk((data && data.podcast_theme && data.podcast_theme.extra_seasons) || next); }, onErr);
    }, onErr);
}

// Latest episodes from every community, newest first; a country id narrows it to that branch
function listGlobal(token, countryId, onOk, onErr) {
    return Http.get(GLOBAL_URL, "/podcast/global", { community_id: countryId > 0 ? countryId : "" }, token, function (data) {
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
        rows.sort(function (a, b) { return a.releaseDate < b.releaseDate ? 1 : a.releaseDate > b.releaseDate ? -1 : 0; });
        // shortcut: newest 60 only, keeps the list light; add paging if users want older
        onOk(rows.slice(0, 60));
    }, onErr);
}

// The list a podcast tab shows: Global and countries aggregate, a platform lists its own.
// No token: premium is hidden anyway, and anonymous requests hit the server cache.
function listFor(baseUrl, communityId, aggregate, onOk, onErr) {
    return aggregate ? listGlobal("", communityId, onOk, onErr) : listAll(baseUrl, communityId, "", onOk, onErr);
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
    // the web looks episodes up by id
    return "https://" + dns + "/podcast?episode=" + encodeURIComponent(String(ep.id));
}

// Port of web buildEpisodePayload
function payload(form, communityId) {
    var num = function (v) { var n = parseInt(String(v || "").replace(/\D/g, ""), 10); return n > 0 ? n : null; };
    var type = form.contentType || "audio";
    var body = {
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
        tags: null
    };
    // app publishes public only; edits keep the episode's access
    if (!form.isEdit) body.access_type = 1;
    // undefined = keep the saved ceiling
    if (form.ceiling !== undefined) body.publish_scope_community_id = Number(form.ceiling) > 0 ? Number(form.ceiling) : null;
    return body;
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
