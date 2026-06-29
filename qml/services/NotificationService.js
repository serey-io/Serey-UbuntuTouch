.pragma library
.import "Http.js" as Http

// Register the Ubuntu Push device token with the Serey backend so the
// server can deliver push notifications to this device.
function registerPushToken(baseUrl, token, pushToken, onOk, onErr) {
    Http.post(baseUrl, "/notification/register-push-token",
              { push_token: pushToken, platform: "ubuntu-touch" },
              token, onOk, onErr);
}

function unregisterPushToken(baseUrl, token, pushToken, onOk, onErr) {
    Http.post(baseUrl, "/notification/unregister-push-token",
              { push_token: pushToken },
              token, onOk, onErr);
}

function listSerey(baseUrl, token, limit, offset, onOk, onErr) {
    Http.get(baseUrl, "/notification/list-by-current-user-for-serey",
             { limit: limit, offset: offset }, token, function (data) {
        onOk((data && (data.data || data.notifications || data.results)) || []);
    }, onErr);
}

function unreadCount(baseUrl, token, onOk, onErr) {
    Http.get(baseUrl, "/notification/unread-count-for-serey",
             {}, token, function (data) {
        onOk((data && (data.data !== undefined ? data.data : (data.count || data.unread_count || 0))) || 0);
    }, onErr);
}

function markAllRead(baseUrl, token, onOk, onErr) {
    Http.put(baseUrl, "/notification/update-read-all-for-serey", {}, token, onOk, onErr);
}

function markOneRead(baseUrl, token, id, onOk, onErr) {
    Http.put(baseUrl, "/notification/update-read-by-id/" + id, {}, token, onOk, onErr);
}
