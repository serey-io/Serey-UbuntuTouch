.pragma library
.import "Http.js" as Http
.import "Mappers.js" as M

/*
 * Post / feed endpoints under /serey-web. The list endpoints accept only
 * `limit` and `offset` (sending community_id is rejected with "Invalid parameter").
 * Responses come back as { posts: [...] }; detail as { content: {...}, replies: [...] }.
 */

function _list(baseUrl, path, params, token, onOk, onErr) {
    Http.get(baseUrl, path, params, token, function (data) {
        var posts = (data.posts || []).map(M.toPost);
        onOk(posts);
    }, onErr);
}

function listTrending(baseUrl, params, token, onOk, onErr) {
    _list(baseUrl, "/serey-web/list-by-trending", params, token, onOk, onErr);
}

function listHot(baseUrl, params, token, onOk, onErr) {
    _list(baseUrl, "/serey-web/list-by-hot", params, token, onOk, onErr);
}

function listNew(baseUrl, params, token, onOk, onErr) {
    _list(baseUrl, "/serey-web/list-by-new", params, token, onOk, onErr);
}

// Gallery: the dedicated /serey-web/list-gallery-post* endpoints reject every
// parameter combination tried ("Invalid parameter"), so we reuse the working
// list-by-new feed and keep only posts that actually carry an image.
function listGallery(baseUrl, params, token, onOk, onErr) {
    Http.get(baseUrl, "/serey-web/list-by-new", params, token, function (data) {
        var posts = (data.posts || []).map(M.toGalleryPost).filter(function (p) {
            return p.images.length > 0;
        });
        onOk(posts);
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
