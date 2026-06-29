.pragma library
.import "Http.js" as Http

function subscribe(baseUrl, token, communityId, onOk, onErr) {
    Http.post(baseUrl, "/community-subscriber/subscribe",
              { community_id: parseInt(communityId) }, token, onOk, onErr);
}

function unsubscribe(baseUrl, token, communityId, onOk, onErr) {
    Http.post(baseUrl, "/community-subscriber/unsubscribe",
              { community_id: parseInt(communityId) }, token, onOk, onErr);
}

// Returns a Set-like object: { "123": true, "456": true, ... } for quick lookup.
function fetchSubscribed(baseUrl, token, onOk, onErr) {
    Http.get(baseUrl, "/community-subscriber/list-by-current-user",
             {}, token, function (data) {
        var list = (data && (data.data || data.communities || data.results)) || [];
        var map = {};
        for (var i = 0; i < list.length; i++) {
            var id = String(list[i].community_id || list[i].id || "");
            if (id) map[id] = true;
        }
        onOk(map);
    }, onErr);
}
