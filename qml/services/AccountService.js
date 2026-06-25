.pragma library
.import "Http.js" as Http
.import "Mappers.js" as M

/*
 * Auth + account endpoints. Login returns { data: { token, user_device_id } }.
 * Authenticated calls send `Authorization: Bearer <token>`.
 */

function login(baseUrl, username, password, onOk, onErr) {
    Http.post(baseUrl, "/auth/login",
              { username: username, password: password }, null, function (data) {
        var token = data.data && data.data.token;
        if (!token) {
            onErr({ message: "Login succeeded but no token was returned." });
            return;
        }
        onOk({ token: token, userDeviceId: data.data.user_device_id });
    }, onErr);
}

function verify(baseUrl, token, onOk, onErr) {
    Http.post(baseUrl, "/auth/authenticated", {}, token, function (data) {
        onOk(data.account || {});
    }, onErr);
}

function logout(baseUrl, token, onOk, onErr) {
    Http.del(baseUrl, "/auth/logout", token, onOk, onErr);
}

function profile(baseUrl, username, token, onOk, onErr) {
    Http.get(baseUrl, "/accounts/details-by-username/" + encodeURIComponent(username),
             null, token, function (data) {
        onOk(M.toUser(username, data.account || {}));
    }, onErr);
}
