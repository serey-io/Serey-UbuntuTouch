.pragma library
.import "Http.js" as Http

/*
 * Voting. All endpoints are JWT-only and signed server-side using the posting
 * key carried in the token (Serey is a Steem-fork blockchain), so the client
 * only sends author/permlink/weight/vote_type.
 *
 *   POST /vote/vote         weight > 0   upvote (or like, when vote_type=comment)
 *   POST /vote/flag         weight < 0   flag / downvote (not allowed on comments)
 *   POST /vote/remove-vote               clear an existing vote
 *
 * `weight` is a percentage 1..100 (web uses a slider; we vote at full strength).
 * Success data: { voter_count, flagger_count, voters[], flaggers[], serey_value }.
 */

function _norm(data) {
    var d = (data && data.data) ? data.data : (data || {});
    return {
        voterCount: (d.voter_count !== undefined) ? d.voter_count
                  : (d.current_vote !== undefined ? d.current_vote : 0),
        flaggerCount: d.flagger_count || 0,
        voters: d.voters || [],
        flaggers: d.flaggers || [],
        payout: d.serey_value || ""
    };
}

function _send(baseUrl, path, body, token, onOk, onErr) {
    Http.post(baseUrl, path, body, token, function (data) {
        onOk(_norm(data));
    }, onErr);
}

function upvote(baseUrl, author, permlink, voteType, token, onOk, onErr) {
    _send(baseUrl, "/vote/vote",
          { author: author, permlink: permlink, weight: 100, vote_type: voteType || "post" },
          token, onOk, onErr);
}

function flag(baseUrl, author, permlink, voteType, token, onOk, onErr) {
    _send(baseUrl, "/vote/flag",
          { author: author, permlink: permlink, weight: -100, vote_type: voteType || "post" },
          token, onOk, onErr);
}

function removeVote(baseUrl, author, permlink, voteType, token, onOk, onErr) {
    _send(baseUrl, "/vote/remove-vote",
          { author: author, permlink: permlink, vote_type: voteType || "post" },
          token, onOk, onErr);
}
