.pragma library
.import "Http.js" as Http

/*
 * Create a comment/reply. JWT-only; the backend broadcasts it to the chain
 * using the token's posting key.
 *
 *   POST /serey-web/create-or-update-comment
 *     { parent_author, parent_permlink, maincategory, body }
 *
 * `maincategory` is the parent post's primary category. Omitting `permlink`
 * creates a new comment (the backend generates one). The response does not
 * echo the created comment, so the UI appends an optimistic local copy.
 */
function create(baseUrl, params, token, onOk, onErr) {
    var body = {
        parent_author: params.parentAuthor,
        parent_permlink: params.parentPermlink,
        maincategory: params.maincategory || "serey",
        body: params.body
    };
    Http.post(baseUrl, "/serey-web/create-or-update-comment", body, token,
              function (data) { onOk(data || {}); }, onErr);
}

/*
 * Delete a comment (or post). JWT-only; the backend authorises against the
 * token's username, so a user can only delete their own comment.
 *
 * Uses the POST alias of /serey-web/delete-post-or-comment: Qt's QML
 * XMLHttpRequest cannot attach a body to a DELETE request, so the backend
 * exposes the same handler over POST for native clients.
 *
 *   POST /serey-web/delete-post-or-comment
 *     { username, permlink }
 */
function remove(baseUrl, permlink, username, token, onOk, onErr) {
    Http.post(baseUrl, "/serey-web/delete-post-or-comment",
              { username: username, permlink: permlink }, token,
              function (data) { onOk(data || {}); }, onErr);
}
