.pragma library

/*
 * Normalises raw Serey API JSON into stable view-models used by the QML.
 * All field-name quirks live here. The API sends several fields as Python-style
 * stringified lists, e.g. image_url = "['https://...']", categories = "['general']",
 * and "None" for nulls — parseList() handles those.
 */

function toInt(v) {
    var n = parseInt(v, 10);
    return isNaN(n) ? 0 : n;
}

function parseList(val) {
    if (!val)
        return [];
    if (Array.isArray(val))
        return val;
    if (typeof val !== "string")
        return [];
    var s = val.trim();
    if (s === "" || s === "None" || s === "[]")
        return [];
    s = s.replace(/^\[/, "").replace(/\]$/, "");
    var parts = s.split(",");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i].trim().replace(/^['"]/, "").replace(/['"]$/, "").trim();
        if (p && p !== "None")
            out.push(p);
    }
    return out;
}

function stripHtml(html, max) {
    if (!html)
        return "";
    var text = String(html)
        .replace(/<[^>]+>/g, " ")
        .replace(/&nbsp;/g, " ")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/\s+/g, " ")
        .trim();
    if (max && text.length > max)
        text = text.substring(0, max).trim() + "…";
    return text;
}

// YouTube's maxresdefault.jpg is missing for many videos (404). hqdefault.jpg
// always exists, so prefer it.
function fixThumb(url) {
    if (url && url.indexOf("img.youtube.com") >= 0)
        return url.replace("maxresdefault", "hqdefault");
    return url;
}

// Pick a thumbnail for a post: explicit list field, else first <img> in the body.
function firstImage(raw) {
    var imgs = parseList(raw.image_url);
    if (imgs.length)
        return fixThumb(imgs[0]);
    if (raw.thumbnail_url)
        return fixThumb(raw.thumbnail_url);
    var desc = raw.description || raw.post_description || "";
    var m = /<img[^>]+src=["']([^"']+)["']/i.exec(desc);
    return m ? fixThumb(m[1]) : "";
}

// Normalise a voters/flaggers list to plain usernames. The API sends either
// ["alice", ...] (detail content) or [{voter:"alice"}, ...] (some endpoints).
function voterNames(arr) {
    if (!arr || !Array.isArray(arr))
        return [];
    var out = [];
    for (var i = 0; i < arr.length; i++) {
        var v = arr[i];
        if (typeof v === "string")
            out.push(v);
        else if (v && v.voter)
            out.push(v.voter);
    }
    return out;
}

function toPost(raw) {
    raw = raw || {};
    return {
        id: raw.id,
        author: raw.author || "",
        permlink: raw.permlink || "",
        title: raw.title || "(untitled)",
        body: raw.description || "",
        excerpt: stripHtml(raw.short_desc || raw.description || "", 180),
        thumbnail: firstImage(raw),
        authorImage: raw.author_image_url || "",
        date: raw.publish_date || "",
        votes: toInt(raw.voter_count),
        comments: toInt(raw.answer_count),
        payout: raw.serey_value || "",
        categories: parseList(raw.categories),
        voters: voterNames(raw.voters),
        flaggers: voterNames(raw.flaggers),
        community: raw.community_title || "",
        checkmark: raw.checkmark_icon || ""
    };
}

// A comment/reply node. Recurses into nested `replies` so the detail page can
// flatten the tree with indentation.
function toComment(raw) {
    raw = raw || {};
    var kids = [];
    if (raw.replies && raw.replies.length) {
        for (var i = 0; i < raw.replies.length; i++)
            kids.push(toComment(raw.replies[i]));
    }
    return {
        author: raw.author || "",
        permlink: raw.permlink || "",
        body: stripHtml(raw.description || raw.body || ""),
        date: raw.publish_date || "",
        votes: toInt(raw.voter_count),
        voters: voterNames(raw.voters),
        authorImage: raw.author_image_url || "",
        replies: kids
    };
}

function toVideo(raw) {
    raw = raw || {};
    return {
        id: raw.id,
        author: raw.username || raw.author || "",
        permlink: raw.permlink || "",
        title: raw.title || "(untitled)",
        body: raw.description || raw.post_description || "",
        excerpt: stripHtml(raw.description || raw.post_description || "", 180),
        thumbnail: fixThumb(raw.thumbnail_url || ""),
        authorImage: raw.author_image_url || raw.post_author_image_url || "",
        date: raw.publish_date || "",
        votes: toInt(raw.voter_count),
        comments: toInt(raw.answer_count),
        payout: raw.serey_value || "",
        embedUrl: raw.embed_video || "",
        videoLink: raw.video_link || "",
        videoId: raw.video_id || "",
        platform: raw.platform_type || "",
        dimensions: raw.dimensions || "16:9",
        community: raw.community_title || ""
    };
}

function toCommunity(raw) {
    raw = raw || {};
    return {
        id: raw.id,
        title: raw.title || "",
        dns: raw.dns || "",
        icon: raw.icon_url || raw.logo_url || "",
        country: raw.country || "",
        level: toInt(raw.level)
    };
}

function toUser(username, raw) {
    raw = raw || {};
    var name = raw.full_name;
    if (!name && typeof raw.name === "string")
        name = raw.name;
    return {
        username: username,
        fullName: name || username,
        bio: raw.bio || "",
        reputation: raw.reputation,
        postCount: toInt(raw.post_count),
        commentCount: toInt(raw.comment_count),
        followers: toInt(raw.followers_count),
        following: toInt(raw.following_count),
        balance: raw.balance || "",
        sereyPower: raw.sereypower || "",
        joinDate: raw.join_date || "",
        profileUrl: raw.profile_url || "",
        coverUrl: raw.cover_image_url || "",
        checkmark: raw.checkmark_icon || "",
        email: raw.email || "",
        phone: raw.phone || ""
    };
}
