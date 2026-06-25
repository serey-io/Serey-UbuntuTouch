.pragma library
.import "Http.js" as Http
.import "Mappers.js" as M

/*
 * Post / feed endpoints under /serey-web. The list endpoints accept only
 * `limit` and `offset` (sending community_id is rejected with "Invalid parameter").
 * Responses come back as { posts: [...] }; detail as { content: {...}, replies: [...] }.
 */

// onOk receives (posts, rawCount). rawCount is the number of rows the server
// returned *before* any client-side filtering, so callers paginate/`endReached`
// against the true server offset rather than a filtered length.
function _list(baseUrl, path, params, token, onOk, onErr) {
    return Http.get(baseUrl, path, params, token, function (data) {
        var raw = data.posts || [];
        onOk(raw.map(M.toPost), raw.length);
    }, onErr);
}

function listTrending(baseUrl, params, token, onOk, onErr) {
    return _list(baseUrl, "/serey-web/list-by-trending", params, token, onOk, onErr);
}

function listHot(baseUrl, params, token, onOk, onErr) {
    return _list(baseUrl, "/serey-web/list-by-hot", params, token, onOk, onErr);
}

function listNew(baseUrl, params, token, onOk, onErr) {
    return _list(baseUrl, "/serey-web/list-by-new", params, token, onOk, onErr);
}

// Gallery: the dedicated image-post feed. Takes limit + offset (offset=0 is
// sent as "0", which the backend accepts), and community_id to narrow by region
// exactly like the blog feeds. Requires only optional auth; the token, when
// present, personalises voters/flaggers state. Mapped via toGalleryPost, which
// already expects this endpoint's fields (image_url, voter_count, serey_value…).
function listGallery(baseUrl, params, token, onOk, onErr) {
    return Http.get(baseUrl, "/serey-web/list-gallery-post-by-new", params, token, function (data) {
        var raw = data.posts || [];
        var posts = raw.map(M.toGalleryPost).filter(function (p) {
            return p.images.length > 0;
        });
        // Pass the RAW server count, not the filtered length, so GalleryPage
        // advances offset correctly (filtering image-less rows must not shrink
        // the next page's offset or it re-requests the same rows forever).
        onOk(posts, raw.length);
    }, onErr);
}

function listByAuthor(baseUrl, author, params, token, onOk, onErr) {
    var p = params || {};
    p.author = author;
    _list(baseUrl, "/serey-web/list-by-author", p, token, onOk, onErr);
}

function detail(baseUrl, author, permlink, token, onOk, onErr) {
    Http.get(baseUrl, "/serey-web/details-by-permlink-and-author",
             { author: author, permlink: permlink }, token, function (data) {
        var content = data.content || {};
        var replies = (data.replies || []).map(M.toComment);
        onOk({ post: M.toPost(content), replies: replies });
    }, onErr);
}
