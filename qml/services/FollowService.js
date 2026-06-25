.pragma library
.import "Http.js" as Http

/*
 * Following another author. `status` is public (no auth) so a feed card can
 * show the current state for any viewer; `toggle` requires the viewer's JWT
 * and flips follow/unfollow server-side based on the current state.
 *
 *   GET  /follow/status               username, author -> { is_following }
 *   POST /follow/follow-or-unfollow   { author, action_type } JWT
 *
 * `action_type` per the API: "follow" | "unfollow".
 */

function status(baseUrl, viewerUsername, author, onOk, onErr) {
    Http.get(baseUrl, "/follow/status", { username: viewerUsername, author: author }, null,
        function (data) {
            onOk(!!(data && (data.is_following || data.following)));
        }, onErr);
}

function toggle(baseUrl, author, isCurrentlyFollowing, token, onOk, onErr) {
    Http.post(baseUrl, "/follow/follow-or-unfollow",
        { author: author, action_type: isCurrentlyFollowing ? "unfollow" : "follow" },
        token,
        function () { onOk(!isCurrentlyFollowing); },
        onErr);
}
